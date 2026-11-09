type t =
  | String of string
  | Int of int
  | Bool of bool
  | Parameters of string
  | Variables of string
  | Concat of t list
  | Resource_id of Resource_id.t
  | Reference of Resource_id.t
  | Property of t * string
  | Call of string * t list

let resource_group_location = Property (Call ("resourceGroup", []), "location")
let quote s = "'" ^ String.concat "''" (String.split_on_char '\'' s) ^ "'"
let call name args = name ^ "(" ^ String.concat ", " args ^ ")"

let resource_id_call id =
  call "resourceId"
    [ quote (Resource_id.type_name id); quote (Resource_id.name id) ]

let rec inner = function
  | String s -> quote s
  | Int i -> string_of_int i
  | Bool b -> call (string_of_bool b) []
  | Parameters name -> call "parameters" [ quote name ]
  | Variables name -> call "variables" [ quote name ]
  | Concat parts -> call "concat" (List.map inner parts)
  | Resource_id id -> resource_id_call id
  | Reference id -> call "reference" [ resource_id_call id ]
  | Property (e, prop) -> inner e ^ "." ^ prop
  | Call (name, args) -> call name (List.map inner args)

let to_string = function
  | String s when String.length s > 0 && s.[0] = '[' -> "[" ^ s
  | String s -> s
  | e -> "[" ^ inner e ^ "]"

let yojson_of_t = function
  | Int i -> `Int i
  | Bool b -> `Bool b
  | e -> `String (to_string e)
