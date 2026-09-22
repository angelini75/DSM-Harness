import sys
import os
import json
import zipfile
import xml.etree.ElementTree as ET
import csv

if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

def inspect_csv(file_path, sample_rows=5):
    encodings = ['utf-8', 'latin-1', 'cp1252']
    text = None
    used_enc = None
    for enc in encodings:
        try:
            with open(file_path, 'r', encoding=enc) as f:
                text = f.read(65536)
                used_enc = enc
                break
        except UnicodeDecodeError:
            continue
    
    if text is None:
        return {"error": "Could not decode CSV with common encodings"}
    
    sniffer = csv.Sniffer()
    try:
        dialect = sniffer.sniff(text[:4096])
        delimiter = dialect.delimiter
    except Exception:
        delimiter = ',' if ',' in text else ';'
        
    lines = text.splitlines()
    reader = csv.reader(lines, delimiter=delimiter)
    rows = list(reader)
    if not rows:
        return {"error": "Empty CSV"}
        
    header = rows[0]
    samples = rows[1:sample_rows+1]
    
    # Count total rows
    total_rows = 0
    with open(file_path, 'r', encoding=used_enc) as f:
        for _ in f:
            total_rows += 1
            
    return {
        "format": "csv",
        "encoding": used_enc,
        "delimiter": delimiter,
        "total_rows": max(0, total_rows - 1),
        "total_columns": len(header),
        "columns": header,
        "sample_data": [dict(zip(header, r[:len(header)])) for r in samples]
    }

def inspect_xlsx(file_path, sample_rows=5):
    try:
        zf = zipfile.ZipFile(file_path, 'r')
    except Exception as e:
        return {"error": f"Failed to open as zip/xlsx: {str(e)}"}
        
    # 1. Read shared strings
    shared_strings = []
    if 'xl/sharedStrings.xml' in zf.namelist():
        tree = ET.fromstring(zf.read('xl/sharedStrings.xml'))
        # Namespace
        ns = {'main': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        for si in tree.findall('.//main:si', ns):
            # Concatenate all <t> in <si>
            t_elems = si.findall('.//main:t', ns)
            val = "".join([t.text or "" for t in t_elems])
            shared_strings.append(val)
            
    # 2. Read workbook to get sheet names and r:ids
    wb_tree = ET.fromstring(zf.read('xl/workbook.xml'))
    wb_ns = {
        'main': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    }
    
    sheets_info = []
    for sheet in wb_tree.findall('.//main:sheet', wb_ns):
        name = sheet.attrib.get('name')
        sheet_id = sheet.attrib.get('sheetId')
        r_id = sheet.attrib.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id')
        sheets_info.append({'name': name, 'sheetId': sheet_id, 'rId': r_id})
        
    # 3. Read rels to map rId to xml filename
    rels_tree = ET.fromstring(zf.read('xl/_rels/workbook.xml.rels'))
    rel_ns = {'rel': 'http://schemas.openxmlformats.org/package/2006/relationships'}
    r_map = {}
    for rel in rels_tree.findall('.//rel:Relationship', rel_ns):
        r_map[rel.attrib.get('Id')] = rel.attrib.get('Target')
        
    results = []
    for s in sheets_info:
        target = r_map.get(s['rId'])
        if not target:
            continue
        # Target might be 'worksheets/sheet1.xml'
        if not target.startswith('xl/'):
            sheet_path = 'xl/' + target
        else:
            sheet_path = target
            
        if sheet_path not in zf.namelist():
            continue
            
        sheet_tree = ET.fromstring(zf.read(sheet_path))
        sheet_ns = {'main': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        
        # Read rows
        rows_data = []
        row_elems = sheet_tree.findall('.//main:row', sheet_ns)
        total_rows = len(row_elems)
        
        for row_elem in row_elems[:sample_rows + 1]:
            row_vals = []
            for c in row_elem.findall('main:c', sheet_ns):
                cell_type = c.attrib.get('t', '')
                v_elem = c.find('main:v', sheet_ns)
                cell_val = v_elem.text if v_elem is not None else ""
                if cell_type == 's' and cell_val.isdigit():
                    idx = int(cell_val)
                    if idx < len(shared_strings):
                        cell_val = shared_strings[idx]
                elif cell_type == 'inlineStr':
                    t_elem = c.find('.//main:t', sheet_ns)
                    cell_val = t_elem.text if t_elem is not None else ""
                row_vals.append(cell_val)
            rows_data.append(row_vals)
            
        if not rows_data:
            results.append({
                "sheet_name": s['name'],
                "total_rows": 0,
                "total_columns": 0,
                "columns": [],
                "sample_data": []
            })
            continue
            
        header = [str(col).strip() for col in rows_data[0]]
        samples = rows_data[1:]
        
        sample_dicts = []
        for r in samples:
            d = {}
            for col_i, col_name in enumerate(header):
                d[col_name] = r[col_i] if col_i < len(r) else ""
            sample_dicts.append(d)
            
        results.append({
            "sheet_name": s['name'],
            "total_rows": max(0, total_rows - 1),
            "total_columns": len(header),
            "columns": header,
            "sample_data": sample_dicts
        })
        
    return {
        "format": "xlsx",
        "sheets": results
    }

def profile_file(file_path):
    if not os.path.exists(file_path):
        return {"error": f"File not found: {file_path}"}
        
    ext = os.path.splitext(file_path)[1].lower()
    if ext == '.csv':
        res = inspect_csv(file_path)
    elif ext in ('.xlsx', '.xls'):
        res = inspect_xlsx(file_path)
    else:
        return {"error": f"Unsupported extension: {ext}"}
        
    res["file_path"] = file_path
    return res

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python inspect_dataset.py <path_to_file>")
        sys.exit(1)
    file_path = sys.argv[1]
    profile = profile_file(file_path)
    print(json.dumps(profile, indent=2, ensure_ascii=False))
