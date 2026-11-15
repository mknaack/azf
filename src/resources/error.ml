module Storage_account = struct
  type t = Missing_name | Invalid_name of string

  let to_string = function
    | Missing_name -> "Storage account name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid storage account name %S: must be 3-24 characters, lowercase \
           letters and digits only"
          name
end

module Server_farm = struct
  type t = Missing_name | Invalid_name of string | Invalid_capacity of int

  let to_string = function
    | Missing_name -> "Server farm name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid server farm name %S: must be 1-60 characters, letters, \
           digits and hyphens only"
          name
    | Invalid_capacity n ->
        Printf.sprintf "Invalid server farm capacity %d: must be at least 1" n
end

module Web_app = struct
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_service_plan
    | Python_requires_linux of string

  let to_string = function
    | Missing_name -> "Web app name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid web app name %S: must be 2-60 characters, letters, digits \
           and hyphens only, not starting or ending with a hyphen"
          name
    | Missing_service_plan -> "Web app service plan is required"
    | Python_requires_linux version ->
        Printf.sprintf "Python %s requires a Linux service plan" version
end

module Log_analytics = struct
  type t = Missing_name | Invalid_name of string | Invalid_retention of int

  let to_string = function
    | Missing_name -> "Log Analytics workspace name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid Log Analytics workspace name %S: must be 4-63 characters, \
           letters, digits and hyphens only, starting and ending with a letter \
           or digit"
          name
    | Invalid_retention days ->
        Printf.sprintf "Invalid Log Analytics retention %d days: must be 30-730"
          days
end

module App_insights = struct
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_workspace
    | Invalid_sampling_percentage of float

  let to_string = function
    | Missing_name -> "App Insights name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid App Insights name %S: must be 1-260 characters, without \
           %%&\\?/ or control characters, not ending with a space or period"
          name
    | Missing_workspace -> "App Insights requires a Log Analytics workspace"
    | Invalid_sampling_percentage p ->
        Printf.sprintf
          "Invalid App Insights sampling percentage %g: must be above 0 and at \
           most 100"
          p
end

type t =
  | Storage_account of Storage_account.t
  | Server_farm of Server_farm.t
  | Web_app of Web_app.t
  | Log_analytics of Log_analytics.t
  | App_insights of App_insights.t

let to_string = function
  | Storage_account e -> Storage_account.to_string e
  | Server_farm e -> Server_farm.to_string e
  | Web_app e -> Web_app.to_string e
  | Log_analytics e -> Log_analytics.to_string e
  | App_insights e -> App_insights.to_string e
