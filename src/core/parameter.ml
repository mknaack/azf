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

let type_to_string = function
  | String -> "string"
  | Secure_string -> "securestring"
  | Int -> "int"
  | Bool -> "bool"

let to_json t =
  ( t.name,
    `Assoc
      (("type", `String (type_to_string t.param_type))
      ::
      (match t.default_value with
      | None -> []
      | Some v -> [ ("defaultValue", v) ])) )
