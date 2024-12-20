## function code 

dashboard_plotting_tool <- function(data, depths = 0.5, tzone = "America/New_York", ylims = c(-5,35), site_name = "", obs_hist, historical_horizon, forecast_horizon_confidence){
  
  data_var <- unique(data$variable)
  num_depths <- length(unique(data$depth))
  
  if(data_var == 'temperature'){
    var_title = 'Water Temperature'
    var_unit = 'Temperature (°C)'
    label_height_adjust <- 1
  } else if(data_var == 'salt'){
    var_title = 'Salinity'
    var_unit = 'Salinity (ppt)'
    label_height_adjust <- 0.01
  } else if(data_var == 'depth'){
    var_title = 'Lake Depth'
    var_unit = 'Depth (m)' 
    label_height_adjust <- 0.5
  } else{
    var_title = 'Water Quality Variable'
    var_unit = 'Variable Unit'
    label_height_adjust <- 1
  }
  
  # Fix dates and rename columns to match plotting code
  curr_tibble <- data |>
    dplyr::filter(depth %in% depths) |>
    dplyr::mutate(datetime = lubridate::with_tz(lubridate::as_datetime(datetime), tzone),
                  reference_datetime = lubridate::with_tz(lubridate::as_datetime(reference_datetime), tzone), 
                  date = as.Date(datetime)) |>#,
    dplyr::filter(datetime >= reference_datetime) |>
    rename(forecast_mean = mean, forecast_sd = sd, forecast_upper_90 = quantile90, forecast_lower_90 = quantile10,
           observed = observation, forecast_start_day = reference_datetime)
  
  priority_date_cutoff <- as.Date(most_recent) + lubridate::days(forecast_horizon_confidence) ## how many days into the forecast do we think we are confident? ALEX we had said 10
  
  primary_forecast_dates <- curr_tibble |> 
    mutate(date_fill = dplyr::if_else(date <= priority_date_cutoff, date, NA)) |> 
    pull(date_fill)
  
  secondary_forecast_dates <- curr_tibble |> 
    mutate(date_fill = dplyr::if_else(date >= priority_date_cutoff, date, NA)) |> 
    pull(date_fill)
  
  curr_tibble$primary_dates <- primary_forecast_dates
  curr_tibble$secondary_dates <- secondary_forecast_dates
  
  
  if (num_depths > 1){
    p <- ggplot2::ggplot(curr_tibble, ggplot2::aes(x = as.Date(date))) +
      ggplot2::ylim(ylims) +
      ggplot2::xlim(c(as.Date(min((curr_tibble$date)) - lubridate::days(historical_horizon)), (as.Date(max(curr_tibble$date)) + lubridate::days(5)))) +
      ggplot2::geom_line(ggplot2::aes(y = forecast_mean, color = as.factor(depth)), size = 0.5)+
      ggplot2::geom_ribbon(ggplot2::aes(x = primary_dates, ymin = forecast_lower_90, ymax = forecast_upper_90,
                                        fill = as.factor(depth)),
                           alpha = 0.3) +
      ggplot2::geom_ribbon(ggplot2::aes(x = secondary_dates, ymin = forecast_lower_90, ymax = forecast_upper_90,
                                        fill = as.factor(depth)),
                           alpha = 0.1) +      
      ggplot2::geom_point(data = obs_hist, ggplot2::aes(x=as.Date(datetime),y = observation, color = as.factor(depth)), size = 2) +
      ggplot2::geom_vline(aes(xintercept = as.Date(forecast_start_day),
                              linetype = "solid"),
                          alpha = 1) +
      ggplot2::annotate(x = as.Date(curr_tibble$forecast_start_day - 72*60*60), y = max(ylims) - label_height_adjust, label = 'Past', geom = 'text') +
      ggplot2::annotate(x = as.Date(curr_tibble$forecast_start_day + 72*60*60), y = max(ylims) - label_height_adjust, label = 'Future', geom = 'text') +
      ggplot2::theme_light() +
      ggplot2::scale_fill_manual(name = "Depth (m)",
                                 values = c("#D55E00", '#009E73', '#0072B2'),
                                 labels = as.character(depths)) +
      ggplot2::scale_color_manual(name = "Depth (m)",
                                  values = c("#D55E00", '#009E73', '#0072B2'),
                                  labels = as.character(depths)) +
      ggplot2::scale_linetype_manual(name = "",
                                     values = c('solid'),
                                     labels = c('Forecast Date')) +
      ggplot2::scale_y_continuous(name = var_unit,
                                  limits = ylims) +
      ggplot2::labs(x = "Date",
                    y = var_unit,
                    fill = 'Depth (m)',
                    color = 'Depth',
                    title = paste0(site_name, ' ',var_title," Forecast, ", lubridate::date(curr_tibble$forecast_start_day))) +#,
      ggplot2::theme(axis.text.x = ggplot2::element_text(size = 10),
                     plot.title = element_text(hjust = 0.5))
    
  } else if (num_depths == 1){
    message('using one depth...')
    
    p <- ggplot2::ggplot(curr_tibble, ggplot2::aes(x = as.Date(date))) +
      ggplot2::ylim(ylims) +
      ggplot2::xlim(c(as.Date(min((curr_tibble$date)) - lubridate::days(historical_horizon)), (as.Date(max(curr_tibble$date)) + lubridate::days(5)))) +
      ggplot2::geom_ribbon(ggplot2::aes(x = primary_dates, ymin = forecast_lower_90, ymax = forecast_upper_90), color = 'lightblue', fill = 'lightblue') +
      ggplot2::geom_ribbon(ggplot2::aes(x = secondary_dates, ymin = forecast_lower_90, ymax = forecast_upper_90), color = 'grey', fill = 'grey') +
      ggplot2::geom_point(data = obs_hist, ggplot2::aes(x=as.Date(datetime),y = observation), color = 'red') +
      ggplot2::geom_vline(aes(xintercept = as.Date(forecast_start_day)),
                          alpha = 1, linetype = "solid") +
      ggplot2::geom_line(ggplot2::aes(y = forecast_mean), color = 'black')+
      ggplot2::annotate(x = as.Date(curr_tibble$forecast_start_day - 72*60*60), y = max(ylims) - label_height_adjust, label = 'Past', geom = 'text') +
      ggplot2::annotate(x = as.Date(curr_tibble$forecast_start_day + 72*60*60), y = max(ylims) - label_height_adjust, label = 'Future', geom = 'text') +
      ggplot2::theme_light() +
      ggplot2::scale_linetype_manual(name = "",
                                     values = c('solid'),
                                     labels = c('Forecast Date')) +
      ggplot2::scale_y_continuous(name = var_unit,
                                  limits = ylims) +
      ggplot2::labs(x = "Date",
                    y = var_unit,
                    title = paste0(site_name, ' ',var_title," Forecast, ", lubridate::date(curr_tibble$forecast_start_day))) +#,
      ggplot2::theme(axis.text.x = ggplot2::element_text(size = 10),
                     plot.title = element_text(hjust = 0.5))
  }
  
  return(p)
}
