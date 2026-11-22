open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

type config = {
  name : string option;
  retention_days : int;
  daily_cap_gb : float option;
  location : Location.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = { workspace_name : string; config : config }

let type_name = "Microsoft.OperationalInsights/workspaces"
let api_version = "2023-09-01"

let default =
  {
    name = None;
    retention_days = 30;
    daily_cap_gb = None;
    location = Resource_group;
    tags = [];
    depends_on = [];
  }

let is_alphanumeric = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true
  | _ -> false

let length_is_ok name = String.length name >= 4 && String.length name <= 63

let has_only_valid_chars name =
  String.for_all (fun ch -> is_alphanumeric ch || ch = '-') name

let starts_and_ends_alphanumeric name =
  is_alphanumeric name.[0] && is_alphanumeric name.[String.length name - 1]

let validate_name name =
  if
    length_is_ok name && has_only_valid_chars name
    && starts_and_ends_alphanumeric name
  then Ok name
  else Error (Error.Log_analytics (Invalid_name name))

let validate_retention days =
  if days >= 30 && days <= 730 then Ok days
  else Error (Error.Log_analytics (Invalid_retention days))

let validate_daily_cap = function
  | Some gb when not (Float.is_finite gb && gb > 0.) ->
      Error (Error.Log_analytics (Invalid_daily_cap gb))
  | _ -> Ok ()

let ( let* ) = Result.bind

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  let* name =
    Option.to_result ~none:(Error.Log_analytics Missing_name) config.name
  in
  let* workspace_name = validate_name name in
  let* _ = validate_retention config.retention_days in
  let* () = validate_daily_cap config.daily_cap_gb in
  Ok { workspace_name; config }

let name name c = { c with name = Some name }
let retention_days retention_days c = { c with retention_days }
let daily_cap_gb gb c = { c with daily_cap_gb = Some gb }
let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id t = Resource_id.make ~type_name t.workspace_name

let customer_id t =
  (Property (Reference (resource_id t), "customerId") : string Arm_expression.t)

type sku = { name : string } [@@deriving yojson_of]

type workspace_capping = { daily_quota_gb : float [@key "dailyQuotaGb"] }
[@@deriving yojson_of]

type properties = {
  sku : sku;
  retention_in_days : int; [@key "retentionInDays"]
  workspace_capping : workspace_capping option;
      [@key "workspaceCapping"] [@yojson.option]
}
[@@deriving yojson_of]

let to_arm_resource { workspace_name; config = c } : Arm_resource.t =
  {
    type_name;
    api_version;
    name = workspace_name;
    location = Some (Location.to_expression c.location);
    tags = c.tags;
    sku = None;
    kind = None;
    depends_on = c.depends_on;
    references = Arm_expression.resource_ids (Location.to_expression c.location);
    parameters = Arm_expression.parameters (Location.to_expression c.location);
    properties =
      yojson_of_properties
        {
          sku = { name = "PerGB2018" };
          retention_in_days = c.retention_days;
          workspace_capping =
            Option.map (fun daily_quota_gb -> { daily_quota_gb }) c.daily_cap_gb;
        };
  }
