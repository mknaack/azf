open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

type config = {
  name : string option;
  workspace : Log_analytics.t option;
  sampling_percentage : float option;
  disable_ip_masking : bool;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = {
  component_name : string;
  workspace : Log_analytics.t;
  config : config;
}

let type_name = "Microsoft.Insights/components"
let api_version = "2020-02-02"

let default =
  {
    name = None;
    workspace = None;
    sampling_percentage = None;
    disable_ip_masking = false;
    location = Arm_expression.resource_group_location;
    tags = [];
    depends_on = [];
  }

let is_invalid_char = function
  | '%' | '&' | '\\' | '?' | '/' -> true
  | ch -> Char.code ch < 32

let validate_name name =
  let length = String.length name in
  if
    length >= 1 && length <= 260
    && (not (String.exists is_invalid_char name))
    && not
         (String.ends_with ~suffix:" " name || String.ends_with ~suffix:"." name)
  then Ok name
  else Error (Error.App_insights (Invalid_name name))

let validate_sampling = function
  | Some p when not (p > 0. && p <= 100.) ->
      Error (Error.App_insights (Invalid_sampling_percentage p))
  | _ -> Ok ()

let ( let* ) = Result.bind

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  let* name =
    Option.to_result ~none:(Error.App_insights Missing_name) config.name
  in
  let* component_name = validate_name name in
  let* workspace =
    Option.to_result ~none:(Error.App_insights Missing_workspace)
      config.workspace
  in
  let* () = validate_sampling config.sampling_percentage in
  Ok { component_name; workspace; config }

let name name c = { c with name = Some name }
let workspace workspace (c : config) = { c with workspace = Some workspace }
let sampling_percentage p c = { c with sampling_percentage = Some p }

let disable_ip_masking disable_ip_masking (c : config) =
  { c with disable_ip_masking }

let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id t = Resource_id.make ~type_name t.component_name
let property t name = Arm_expression.Property (Reference (resource_id t), name)
let instrumentation_key t = property t "InstrumentationKey"
let connection_string t = property t "ConnectionString"

type properties = {
  application_type : string; [@key "Application_Type"]
  workspace_resource_id : Arm_expression.t; [@key "WorkspaceResourceId"]
  ingestion_mode : string; [@key "IngestionMode"]
  disable_ip_masking : bool; [@key "DisableIpMasking"]
  sampling_percentage : float option;
      [@key "SamplingPercentage"] [@yojson.option]
}
[@@deriving yojson_of]

let to_arm_resource { component_name; workspace; config = c } : Arm_resource.t =
  let workspace_id =
    Arm_expression.Resource_id (Log_analytics.resource_id workspace)
  in
  let expressions = [ c.location; workspace_id ] in
  {
    type_name;
    api_version;
    name = component_name;
    location = Some c.location;
    tags = c.tags;
    sku = None;
    kind = Some "web";
    depends_on = c.depends_on;
    references = List.concat_map Arm_expression.resource_ids expressions;
    parameters = List.concat_map Arm_expression.parameters expressions;
    properties =
      yojson_of_properties
        {
          application_type = "web";
          workspace_resource_id = workspace_id;
          ingestion_mode = "LogAnalytics";
          disable_ip_masking = c.disable_ip_masking;
          sampling_percentage = c.sampling_percentage;
        };
  }
