type output_type = String | Int | Bool
type t = { name : string; output_type : output_type; value : Arm_expression.t }

let string name value = { name; output_type = String; value }
let int name value = { name; output_type = Int; value }
let bool name value = { name; output_type = Bool; value }

let yojson_of_output_type = function
  | String -> `String "string"
  | Int -> `String "int"
  | Bool -> `String "bool"

type definition = {
  output_type : output_type; [@key "type"]
  value : Arm_expression.t;
}
[@@deriving yojson_of]

let to_definition ({ name; output_type; value } : t) =
  (name, yojson_of_definition { output_type; value })
