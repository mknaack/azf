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

type parameter = {
  type_name : string; [@key "type"]
  default_value : Arm_expression.t option; [@key "defaultValue"] [@yojson.option]
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
    { type_name = Parameter.type_name p; default_value = p.default_value } )

let to_output (o : Output.t) : string * output =
  (o.name, { type_name = Output.type_name o; value = o.value })

let to_string (d : t) =
  yojson_of_template
    {
      schema;
      content_version = "1.0.0.0";
      parameters = List.map to_parameter d.parameters;
      resources = d.resources;
      outputs = List.map to_output d.outputs;
    }
  |> Yojson.Safe.pretty_to_string
