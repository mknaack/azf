type output_type = String | Int | Bool
type t = { name : string; output_type : output_type; value : Arm_expression.t }

let string name value = { name; output_type = String; value }
let int name value = { name; output_type = Int; value }
let bool name value = { name; output_type = Bool; value }

let type_to_string = function
  | String -> "string"
  | Int -> "int"
  | Bool -> "bool"

let to_json t =
  ( t.name,
    `Assoc
      [
        ("type", `String (type_to_string t.output_type));
        ("value", Arm_expression.to_json t.value);
      ] )
