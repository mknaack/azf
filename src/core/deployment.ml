open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  resources : Arm_resource.t list;
  parameters : Parameter.t list;
  outputs : Output.t list;
}

let empty = { resources = []; parameters = []; outputs = [] }
let build transformers = List.fold_left (fun d f -> f d) empty transformers
let add_resources rs d = { d with resources = d.resources @ rs }
let add_resource r = add_resources [ r ]
let add_parameter p d = { d with parameters = d.parameters @ [ p ] }
let add_output o d = { d with outputs = d.outputs @ [ o ] }

let schema =
  "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"

type value = Parameter.Value.t

let yojson_of_value = Parameter.Value.yojson_of_t
let is_empty = function [] -> true | _ :: _ -> false

type metadata = { description : string } [@@deriving yojson_of]

type parameter = {
  type_name : string; [@key "type"]
  default_value : value option; [@key "defaultValue"] [@yojson.option]
  allowed_values : value list; [@key "allowedValues"] [@yojson_drop_if is_empty]
  min_value : int option; [@key "minValue"] [@yojson.option]
  max_value : int option; [@key "maxValue"] [@yojson.option]
  min_length : int option; [@key "minLength"] [@yojson.option]
  max_length : int option; [@key "maxLength"] [@yojson.option]
  metadata : metadata option; [@yojson.option]
}
[@@deriving yojson_of]

type output = { type_name : string; [@key "type"] value : Arm_expression.t }
[@@deriving yojson_of]

type 'a named = (string * 'a) list

let yojson_of_named yojson_of_value (named : _ named) =
  `Assoc (List.map (fun (name, value) -> (name, yojson_of_value value)) named)

type template = {
  schema : string; [@key "$schema"]
  content_version : string; [@key "contentVersion"]
  parameters : parameter named;
  resources : Arm_resource.t list;
  outputs : output named;
}
[@@deriving yojson_of]

let to_parameter (p : Parameter.t) =
  ( p.name,
    {
      type_name = Parameter.Type.to_string p.param_type;
      default_value = p.default_value;
      allowed_values = p.allowed_values;
      min_value = p.min_value;
      max_value = p.max_value;
      min_length = p.min_length;
      max_length = p.max_length;
      metadata = Option.map (fun description -> { description }) p.description;
    } )

let all_parameters (d : t) =
  let add params (p : Parameter.t) =
    if List.exists (fun (q : Parameter.t) -> String.equal p.name q.name) params
    then params
    else params @ [ p ]
  in
  List.fold_left add []
    (d.parameters
    @ List.concat_map (fun (r : Arm_resource.t) -> r.parameters) d.resources
    @ List.concat_map
        (fun (o : Output.t) -> Arm_expression.parameters o.value)
        d.outputs)

let to_output (o : Output.t) : string * output =
  (o.name, { type_name = Output.Type.to_string o.output_type; value = o.value })

let infer_depends_on resources (r : Arm_resource.t) =
  let deployed id =
    List.exists
      (fun other -> Resource_id.equal id (Arm_resource.resource_id other))
      resources
  in
  let self = Arm_resource.resource_id r in
  let add depends_on id =
    if
      deployed id
      && (not (Resource_id.equal id self))
      && not (List.exists (Resource_id.equal id) depends_on)
    then depends_on @ [ id ]
    else depends_on
  in
  { r with depends_on = List.fold_left add r.depends_on r.references }

let to_string (d : t) =
  yojson_of_template
    {
      schema;
      content_version = "1.0.0.0";
      parameters = List.map to_parameter (all_parameters d);
      resources = List.map (infer_depends_on d.resources) d.resources;
      outputs = List.map to_output d.outputs;
    }
  |> Yojson.Safe.pretty_to_string
