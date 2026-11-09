type t = {
  type_name : string;
  api_version : string;
  name : string;
  location : Arm_expression.t option;
  tags : (string * string) list;
  sku : Yojson.Safe.t option;
  kind : string option;
  depends_on : Resource_id.t list;
  properties : Yojson.Safe.t;
}

let resource_id t = Resource_id.make ~type_name:t.type_name t.name
let field key = Option.map (fun value -> (key, value))
let non_empty key = function [] -> None | l -> Some (key, `List l)

let to_json t =
  `Assoc
    (List.filter_map Fun.id
       [
         Some ("type", `String t.type_name);
         Some ("apiVersion", `String t.api_version);
         Some ("name", `String t.name);
         field "location" (Option.map Arm_expression.to_json t.location);
         (match t.tags with
         | [] -> None
         | tags ->
             Some ("tags", `Assoc (List.map (fun (k, v) -> (k, `String v)) tags)));
         field "sku" t.sku;
         field "kind" (Option.map (fun k -> `String k) t.kind);
         non_empty "dependsOn"
           (List.map
              (fun id -> Arm_expression.(to_json (Resource_id id)))
              t.depends_on);
         Some ("properties", t.properties);
       ])
