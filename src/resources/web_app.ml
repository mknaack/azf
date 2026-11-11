open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

module Runtime = struct
  type t =
    | Dotnet of string
    | Node of string
    | Python of string
    | Java of string
    | Php of string

  let to_string = function
    | Dotnet v -> "DOTNETCORE|" ^ v
    | Node v -> "NODE|" ^ v
    | Python v -> "PYTHON|" ^ v
    | Java v -> "JAVA|" ^ v
    | Php v -> "PHP|" ^ v
end

module Error = struct
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_service_plan
    | Unsupported_runtime of Runtime.t

  let to_string = function
    | Missing_name -> "Web app name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid web app name %S: must be 2-60 characters, letters, digits \
           and hyphens only, not starting or ending with a hyphen"
          name
    | Missing_service_plan -> "Web app service plan is required"
    | Unsupported_runtime runtime ->
        Printf.sprintf "Runtime %s is not supported on Windows plans"
          (Runtime.to_string runtime)
end

type config = {
  name : string option;
  service_plan : Server_farm.t option;
  https_only : bool;
  always_on : bool;
  runtime : Runtime.t option;
  app_settings : (string * Arm_expression.t) list;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = { app_name : string; plan : Server_farm.t; config : config }

let type_name = "Microsoft.Web/sites"
let api_version = "2022-09-01"

let default =
  {
    name = None;
    service_plan = None;
    https_only = true;
    always_on = false;
    runtime = None;
    app_settings = [];
    location = Arm_expression.resource_group_location;
    tags = [];
    depends_on = [];
  }

let is_name_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' -> true
  | _ -> false

let validate_name name =
  let length = String.length name in
  if
    length >= 2 && length <= 60
    && String.for_all is_name_char name
    && name.[0] <> '-'
    && name.[length - 1] <> '-'
  then Ok name
  else Error (Error.Invalid_name name)

let ( let* ) = Result.bind

let check_runtime plan = function
  | Some (Runtime.Python _ as runtime) when not (Server_farm.is_linux plan) ->
      Error (Error.Unsupported_runtime runtime)
  | _ -> Ok ()

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  let* name = Option.to_result ~none:Error.Missing_name config.name in
  let* app_name = validate_name name in
  let* plan =
    Option.to_result ~none:Error.Missing_service_plan config.service_plan
  in
  let* () = check_runtime plan config.runtime in
  Ok { app_name; plan; config }

let name name c = { c with name = Some name }
let service_plan plan c = { c with service_plan = Some plan }
let https_only https_only c = { c with https_only }
let always_on always_on c = { c with always_on }
let runtime runtime c = { c with runtime = Some runtime }

let add_settings settings c =
  let replaced (key, _) = List.mem_assoc key settings in
  {
    c with
    app_settings = List.filter (Fun.negate replaced) c.app_settings @ settings;
  }

let add_setting key value = add_settings [ (key, value) ]
let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id t = Resource_id.make ~type_name t.app_name

let default_host_name t =
  Arm_expression.Property (Reference (resource_id t), "defaultHostName")

type app_setting = { name : string; value : Arm_expression.t }
[@@deriving yojson_of]

type site_config = {
  always_on : bool; [@key "alwaysOn"]
  linux_fx_version : string option; [@key "linuxFxVersion"] [@yojson.option]
  net_framework_version : string option;
      [@key "netFrameworkVersion"] [@yojson.option]
  node_version : string option; [@key "nodeVersion"] [@yojson.option]
  php_version : string option; [@key "phpVersion"] [@yojson.option]
  java_version : string option; [@key "javaVersion"] [@yojson.option]
  java_container : string option; [@key "javaContainer"] [@yojson.option]
  java_container_version : string option;
      [@key "javaContainerVersion"] [@yojson.option]
  min_tls_version : string; [@key "minTlsVersion"]
  app_settings : app_setting list;
      [@key "appSettings"] [@yojson_drop_if List.is_empty]
}
[@@deriving yojson_of]

type properties = {
  server_farm_id : Arm_expression.t; [@key "serverFarmId"]
  https_only : bool; [@key "httpsOnly"]
  site_config : site_config; [@key "siteConfig"]
}
[@@deriving yojson_of]

let site_config ~linux ~always_on ~app_settings runtime =
  let none =
    {
      always_on;
      linux_fx_version = None;
      net_framework_version = None;
      node_version = None;
      php_version = None;
      java_version = None;
      java_container = None;
      java_container_version = None;
      min_tls_version = "1.2";
      app_settings;
    }
  in
  match runtime with
  | None -> none
  | Some runtime when linux ->
      { none with linux_fx_version = Some (Runtime.to_string runtime) }
  | Some (Runtime.Dotnet v) -> { none with net_framework_version = Some v }
  | Some (Runtime.Node v) -> { none with node_version = Some v }
  | Some (Runtime.Php v) -> { none with php_version = Some v }
  | Some (Runtime.Java v) ->
      {
        none with
        java_version = Some v;
        java_container = Some "JAVA";
        java_container_version = Some "SE";
      }
  | Some (Runtime.Python _) -> none

let to_arm_resource { app_name; plan; config = c } : Arm_resource.t =
  let plan_id = Server_farm.resource_id plan in
  {
    type_name;
    api_version;
    name = app_name;
    location = Some c.location;
    tags = c.tags;
    sku = None;
    kind = Some (if Server_farm.is_linux plan then "app,linux" else "app");
    depends_on = c.depends_on;
    references =
      List.concat_map Arm_expression.resource_ids
        (c.location :: Resource_id plan_id :: List.map snd c.app_settings);
    properties =
      yojson_of_properties
        {
          server_farm_id = Resource_id plan_id;
          https_only = c.https_only;
          site_config =
            site_config
              ~linux:(Server_farm.is_linux plan)
              ~always_on:c.always_on
              ~app_settings:
                (List.map (fun (name, value) -> { name; value }) c.app_settings)
              c.runtime;
        };
  }
