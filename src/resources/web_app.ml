open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

module Error = struct
  type t = Missing_name | Invalid_name of string | Missing_service_plan

  let to_string = function
    | Missing_name -> "Web app name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid web app name %S: must be 2-60 characters, letters, digits \
           and hyphens only, not starting or ending with a hyphen"
          name
    | Missing_service_plan -> "Web app service plan is required"
end

type config = {
  name : string option;
  service_plan : Server_farm.t option;
  https_only : bool;
  always_on : bool;
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

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  match (config.name, config.service_plan) with
  | None, _ -> Error Error.Missing_name
  | Some name, plan -> (
      match (validate_name name, plan) with
      | Error e, _ -> Error e
      | Ok _, None -> Error Error.Missing_service_plan
      | Ok app_name, Some plan -> Ok { app_name; plan; config })

let name name c = { c with name = Some name }
let service_plan plan c = { c with service_plan = Some plan }
let https_only https_only c = { c with https_only }
let always_on always_on c = { c with always_on }

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
    depends_on =
      plan_id
      :: List.filter (fun id -> not (Resource_id.equal id plan_id)) c.depends_on;
    properties =
      yojson_of_properties
        {
          server_farm_id = Resource_id plan_id;
          https_only = c.https_only;
          site_config =
            {
              always_on = c.always_on;
              min_tls_version = "1.2";
              app_settings =
                List.map (fun (name, value) -> { name; value }) c.app_settings;
            };
        };
  }
