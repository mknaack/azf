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

let emit d =
  `Assoc
    [
      ("$schema", `String schema);
      ("contentVersion", `String "1.0.0.0");
      ("parameters", `Assoc (List.map Parameter.to_json d.parameters));
      ("resources", `List (List.map Arm_resource.to_json d.resources));
      ("outputs", `Assoc (List.map Output.to_json d.outputs));
    ]
