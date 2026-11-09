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

type definitions = (string * Yojson.Safe.t) list

let yojson_of_definitions definitions = `Assoc definitions

type template = {
  schema : string; [@key "$schema"]
  content_version : string; [@key "contentVersion"]
  parameters : definitions;
  resources : Arm_resource.t list;
  outputs : definitions;
}
[@@deriving yojson_of]

let emit (d : t) =
  yojson_of_template
    {
      schema;
      content_version = "1.0.0.0";
      parameters = List.map Parameter.to_definition d.parameters;
      resources = d.resources;
      outputs = List.map Output.to_definition d.outputs;
    }
