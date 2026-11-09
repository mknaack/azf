type param_type = String | Secure_string | Int | Bool

type t = {
  name : string;
  param_type : param_type;
  default_value : Arm_expression.t option;
}

let make param_type default_value name = { name; param_type; default_value }

let string ?default name =
  make String (Option.map (fun s -> Arm_expression.String s) default) name

let secure_string name = make Secure_string None name

let int ?default name =
  make Int (Option.map (fun i -> Arm_expression.Int i) default) name

let bool ?default name =
  make Bool (Option.map (fun b -> Arm_expression.Bool b) default) name

let to_expression t = Arm_expression.Parameters t.name

let type_name t =
  match t.param_type with
  | String -> "string"
  | Secure_string -> "securestring"
  | Int -> "int"
  | Bool -> "bool"
