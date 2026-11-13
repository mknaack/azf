module Type = struct
  type t = String | Int | Bool | Array | Object

  let to_string = function
    | String -> "string"
    | Int -> "int"
    | Bool -> "bool"
    | Array -> "array"
    | Object -> "object"
end

type t = { name : string; output_type : Type.t; value : Arm_expression.t }

let make output_type name value = { name; output_type; value }
let string = make String
let int = make Int
let bool = make Bool
let array = make Array
let object_ = make Object
