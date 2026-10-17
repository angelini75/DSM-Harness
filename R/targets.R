# ==============================================================================
# DSM-Harness v2 | R/targets.R
# Shared target identification and raster inspection utilities
# ==============================================================================

#' Generate canonical target identifier across pipeline steps
#'
#' @param property Target property name (character)
#' @param d1 Top depth in cm (numeric or character)
#' @param d2 Bottom depth in cm (numeric or character)
#' @return Canonical target identifier string (e.g. 'clay_0_30')
get_target_id <- function(property, d1, d2) {
  safe_prop <- gsub("[^A-Za-z0-9_-]", "_", as.character(property))
  d1_num <- suppressWarnings(as.numeric(d1))
  d1_str <- if (!is.na(d1_num)) gsub("\\.", "_", as.character(d1_num)) else gsub("[^A-Za-z0-9_-]", "_", as.character(d1))
  d2_num <- suppressWarnings(as.numeric(d2))
  d2_str <- if (!is.na(d2_num)) gsub("\\.", "_", as.character(d2_num)) else gsub("[^A-Za-z0-9_-]", "_", as.character(d2))
  sprintf("%s_%s_%s", safe_prop, d1_str, d2_str)
}

#' Parse COG / GeoTIFF layout and technical metadata via terra::describe
#'
#' @param file_path Path to raster GeoTIFF file
#' @return List of parsed technical attributes
parse_cog_attributes <- function(file_path) {
  if (!file.exists(file_path)) return(NULL)
  desc <- terra::describe(file_path)
  
  has_layout_cog <- any(grepl("LAYOUT=COG", desc))
  
  comp_line <- grep("COMPRESSION=", desc, value = TRUE)
  compression <- if (length(comp_line) > 0) sub(".*COMPRESSION=([A-Za-z0-9_-]+).*", "\\1", comp_line[1]) else "UNKNOWN"
  
  pred_line <- grep("PREDICTOR=", desc, value = TRUE)
  predictor <- if (length(pred_line) > 0) sub(".*PREDICTOR=([0-9]+).*", "\\1", pred_line[1]) else "UNKNOWN"
  
  block_line <- grep("Block=[0-9]+x[0-9]+", desc, value = TRUE)
  block <- if (length(block_line) > 0) sub(".*Block=([0-9]+x[0-9]+).*", "\\1", block_line[1]) else "UNKNOWN"
  
  nodata_line <- grep("NoData Value=", desc, value = TRUE)
  nodata <- if (length(nodata_line) > 0) sub(".*NoData Value=([^ ,]+).*", "\\1", nodata_line[1]) else "UNKNOWN"
  
  list(
    is_cog = has_layout_cog,
    layout = if (has_layout_cog) "COG" else "STANDARD",
    compression = compression,
    predictor = predictor,
    block = block,
    nodata = nodata
  )
}
