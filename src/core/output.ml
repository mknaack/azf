type output_type = String | Int | Bool
type t = { name : string; output_type : output_type; value : Arm_expression.t }

let string name value = { name; output_type = String; value }
let int name value = { name; output_type = Int; value }
let bool name value = { name; output_type = Bool; value }

let type_name t =
  match t.output_type with String -> "string" | Int -> "int" | Bool -> "bool"
