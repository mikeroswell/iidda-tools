
# staging
staging = list(
  api_url = "https://math.mcmaster.ca",
  base_path = "iidda/api"
)

# local development
local = list(
  api_url = "http://127.0.0.1:8000",
  base_path = ""
)

# production environment
production = local

#' @importFrom stats setNames
#' @importFrom readr cols
#' @importFrom httr content
#' @importFrom rapiclient get_api get_operations set_default_args_list
#' @importFrom iidda list_xpath rm_trailing_slash

make_ops_list = function(api_url, base_path) {
  handle_iidda_response <- function(x) {
    content_type <- x$headers$`content-type`
    if (content_type == 'application/json') {
      return(httr::content(x))
    }
    else if (content_type == 'text/plain; charset=utf-8') {
      return(httr::content(x
        , type = "text/csv"
        , encoding = "UTF-8"
        , col_types = readr::cols(.default = "c") # read all columns in as strings
        , na = character() # nothing is missing, only blank
      ))
    }
    else {
      return(httr::content(x))
    }
  }

  summary_to_function_name = function(x) {
    gsub(pattern = " ", replacement = "_", tolower(x))
  }

  iidda_api = try(
    rapiclient::get_api(
      url = file.path(
        iidda::rm_trailing_slash(file.path(api_url, base_path)),
        'openapi.json'
      )
    ),
    silent = TRUE
  )

  if (class(iidda_api)[1] == 'try-error') return(iidda_api)

  iidda_api$basePath = file.path('',  base_path)

  raw_requests = rapiclient::get_operations(
    iidda_api,
    handle_response = handle_iidda_response
  )

  parameter_list <- function(x) {
    parameters <- environment(raw_requests[[x]])[["op_def"]][["parameters"]]
    default_values <- list()
    for (parameter in parameters) {
      if (parameter[["required"]] == FALSE) {
        default_values[[parameter[["name"]]]] =
          parameter[["schema"]][["default"]]
      } else {
        next
      }
    }
    return(default_values)
  }

  for (name in names(raw_requests)) {
    raw_requests[[name]] <- rapiclient::set_default_args_list(
      raw_requests[[name]],
      parameter_list(name)
    )
  }

  get_request_names = summary_to_function_name(
    iidda::list_xpath(iidda_api$paths, 'get', 'summary')
  )
  post_request_names = summary_to_function_name(
    iidda::list_xpath(iidda_api$paths, 'post', 'summary')
  )
  request_names = ifelse(
    get_request_names == "list()",
    post_request_names,
    get_request_names
  )
  setNames(raw_requests, request_names)
}

#' \pkg{iidda.api}
#'
#' R binding to the IIDDA API.
#'
"_PACKAGE"

#' IIDDA API Operations
#' @name ops
NULL

#' @importFrom iidda list_xpath
#' @describeIn ops List containing available operations from the IIDDA API
#' as \code{R} functions
#' @export
ops = try(do.call(make_ops_list, production), silent = TRUE)

#' @describeIn ops Operations list for a local development environment,
#' if it exists
#' @export
ops_local = try(do.call(make_ops_list, local), silent = TRUE)

#' @describeIn ops Operations list for a staging environment, if it exists
#' @export
ops_staging = try(do.call(make_ops_list, staging), silent = TRUE)

#' @describeIn ops Print link to interactive documentation for the IIDDA API (not currently up)
#' @export
docs_url = try(file.path(production$api_url, "docs"), silent = TRUE)

#' @describeIn ops Print link to interactive documentation for a development environment
#' @export
docs_url_local = try(file.path(local$api_url, "docs"), silent = TRUE)

#' @describeIn ops Print link to interactive documentation for a staging environment, if it exists
#' @export
docs_url_staging = try(file.path(staging$api_url, "docs"), silent = TRUE)
