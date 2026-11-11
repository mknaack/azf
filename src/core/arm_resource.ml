open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type json = Yojson.Safe.t

let yojson_of_json json = json

type tags = (string * string) list

let yojson_of_tags tags =
  `Assoc (List.map (fun (key, value) -> (key, `String value)) tags)

type dependency = Resource_id.t

let yojson_of_dependency id = Arm_expression.(yojson_of_t (Resource_id id))
let is_empty = function [] -> true | _ :: _ -> false

type t = {
  type_name : string;
  api_version : string;
  name : string;
  location : Arm_expression.t option;
  tags : tags;
  sku : Sku.t option;
  kind : string option;
  depends_on : dependency list;
  references : Resource_id.t list;
  properties : json;
}

type template_resource = {
  type_name : string; [@key "type"]
  api_version : string; [@key "apiVersion"]
  name : string;
  location : Arm_expression.t option; [@yojson.option]
  tags : tags; [@yojson_drop_if is_empty]
  sku : Sku.t option; [@yojson.option]
  kind : string option; [@yojson.option]
  depends_on : dependency list; [@key "dependsOn"] [@yojson_drop_if is_empty]
  properties : json;
}
[@@deriving yojson_of]

let yojson_of_t (t : t) =
  yojson_of_template_resource
    {
      type_name = t.type_name;
      api_version = t.api_version;
      name = t.name;
      location = t.location;
      tags = t.tags;
      sku = t.sku;
      kind = t.kind;
      depends_on = t.depends_on;
      properties = t.properties;
    }

let resource_id (t : t) = Resource_id.make ~type_name:t.type_name t.name
let to_string t = Yojson.Safe.pretty_to_string (yojson_of_t t)
