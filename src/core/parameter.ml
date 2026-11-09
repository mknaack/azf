type param_type = String | Secure_string | Int | Bool

type t = {
  name : string;
  param_type : param_type;
  default_value : Yojson.Safe.t option;
}

let make param_type default_value name = { name; param_type; default_value }

let string ?default name =
  make String (Option.map (fun s -> `String s) default) name

let secure_string name = make Secure_string None name
let int ?default name = make Int (Option.map (fun i -> `Int i) default) name
let bool ?default name = make Bool (Option.map (fun b -> `Bool b) default) name
let to_expression t = Arm_expression.Parameters t.name

let yojson_of_param_type = function
  | String -> `String "string"
  | Secure_string -> `String "securestring"
  | Int -> `String "int"
  | Bool -> `String "bool"

type json = Yojson.Safe.t

let yojson_of_json json = json

type definition = {
  param_type : param_type; [@key "type"]
  default_value : json option; [@key "defaultValue"] [@yojson.option]
}
[@@deriving yojson_of]

let to_definition ({ name; param_type; default_value } : t) =
  (name, yojson_of_definition { param_type; default_value })
