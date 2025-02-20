#' Gets the names of a dataframe's columns of a certain class
#'
#' @param df dataframe
#' @param class_name the R class to return columns of
#' @return names of columns of class 
#' @noRd
getColNameOfClass <- function(df, class_name){
  stopifnot(inherits(df, "data.frame"),
            inherits(class_name, "character"))
  
  names(df)[vapply(df, class, "string") == class_name]
}


#' Aggregate a Google Analytics dataframe over inputted columns
#' 
#' A helper function to aggregate over dimensions
#'
#' @param ga_data A dataframe of data to aggregate
#' @param agg_names The columns to aggregate over
#' @param mean_regex The regex for column names to do mean() rather than sum()
#'
#' @details
#'   Will auto select metrics if they are numeric class columns.
#'   Will auto perform mean aggregation it metric names match \code{mean_regex} argument
#'   If agg_names is NULL will aggregate over all
#'
#' @importFrom magrittr %>%
#' @importFrom rlang !!!
#' @export
#' @import assertthat
#' @examples 
#' 
#' \dontrun{
#' 
#' # use `aggregateGAData` so you can on the fly create summary data
#' ga_data <- google_analytics(81416156, 
#'                             date_range = c("10daysAgo", "yesterday"),
#'                             metrics = "sessions", dimensions = c("hour","date"))
#'                             
#' # if we want totals per hour over the dates:
#' aggregateGAData(ga_data[,c("hour","sessions")], agg_names = "hour")
#' 
#' # it knows not to sum metrics that are rates:
#' aggregateGAData(ga_data[,c("hour","bounceRate")], agg_names = "hour")
#' 
#' 
#' }
aggregateGAData <- function(ga_data, 
                            agg_names=NULL,
                            mean_regex="^avg|^percent|Rate$|^CPC$|^CTR$|^CPM$|^RPC$|^ROI$|^ROAS$|Per"){
  
  assert_that(is.data.frame(ga_data))
  assert_that_ifnn(agg_names, is.character)
  
  metrics <- getColNameOfClass(ga_data, "numeric")
  mean_metrics <- metrics[grepl(mean_regex, metrics)]
  sum_metrics  <- metrics[!grepl(mean_regex, metrics)]
  
  date_col <- getColNameOfClass(ga_data, "Date")
  
  ## do aggregations
  mean_selects <- lapply(c(agg_names, mean_metrics), as.symbol)
  sum_selects <- lapply(c(agg_names, sum_metrics), as.symbol)
  date_selects <- lapply(c(agg_names, date_col), as.symbol)
  
  dots <- lapply(agg_names, as.symbol)

  ## metrics to take mean as per mean_regex
  meanAgg <- ga_data %>%
    dplyr::select(!!!mean_selects) %>%
    dplyr::group_by(!!!dots) %>%
    dplyr::summarise_all(list(~mean(., na.rm = TRUE))) %>% dplyr::ungroup()  
  
  ## metrics to sum over
  sumAgg <- ga_data %>%
    dplyr::select(!!!sum_selects) %>%
    dplyr::group_by(!!!dots) %>%
    dplyr::summarise_all(list(~sum(., na.rm = TRUE))) %>% dplyr::ungroup()    
  
  ## date dimensions take the first entry
  dateAgg <- ga_data %>%
    dplyr::select(!!!date_selects) %>%
    dplyr::group_by(!!!dots) %>%
    dplyr::summarise_all(list(~min(., na.rm = TRUE))) %>% dplyr::ungroup()    
  
  ## join up all the aggregations
  if(!is.null(agg_names)){
    ga_agg <- dplyr::left_join(sumAgg, meanAgg, by = agg_names) %>%
      dplyr::left_join(dateAgg, by = agg_names)
  } else {
    sumAgg  <- if(ncol(sumAgg) == 0) NULL else sumAgg
    meanAgg <- if(ncol(meanAgg) == 0) NULL else meanAgg
    dateAgg <- if(ncol(dateAgg) == 0) NULL else dateAgg
    
    ga_agg <- dplyr::bind_cols(sumAgg, meanAgg, dateAgg)
  }
  
  ga_agg
  
}
