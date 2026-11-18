module Value = struct
  type t =
    | String of string
    | Int of int
    | Bool of bool
    | Array of t list
    | Object of (string * t) list

  let rec yojson_of_t = function
    | String s -> `String s
    | Int i -> `Int i
    | Bool b -> `Bool b
    | Array values -> `List (List.map yojson_of_t values)
    | Object fields ->
        `Assoc (List.map (fun (key, value) -> (key, yojson_of_t value)) fields)
end

module Type = struct
  type _ t =
    | String : string t
    | Secure_string : Arm_type.secure_string t
    | Int : int t
    | Bool : bool t
    | Array : Arm_type.array_ t
    | Object : Arm_type.object_ t
    | Secure_object : Arm_type.secure_object t

  let to_string : type a. a t -> string = function
    | String -> "string"
    | Secure_string -> "securestring"
    | Int -> "int"
    | Bool -> "bool"
    | Array -> "array"
    | Object -> "object"
    | Secure_object -> "secureObject"
end

type 'a t = {
  name : string;
  param_type : 'a Type.t;
  default_value : Value.t option;
  allowed_values : Value.t list;
  description : string option;
  min_value : int option;
  max_value : int option;
  min_length : int option;
  max_length : int option;
}

type any = Any : _ t -> any

let name (Any p) = p.name

let make ?default_value ?(allowed_values = []) ?description ?min_value
    ?max_value ?min_length ?max_length param_type name =
  {
    name;
    param_type;
    default_value;
    allowed_values;
    description;
    min_value;
    max_value;
    min_length;
    max_length;
  }

let string ?default ?(allowed = []) ?description ?min_length ?max_length name =
  make
    ?default_value:(Option.map (fun s -> Value.String s) default)
    ~allowed_values:(List.map (fun s -> Value.String s) allowed)
    ?description ?min_length ?max_length String name

let secure_string ?description ?min_length ?max_length name =
  make ?description ?min_length ?max_length Secure_string name

let int ?default ?(allowed = []) ?description ?min_value ?max_value name =
  make
    ?default_value:(Option.map (fun i -> Value.Int i) default)
    ~allowed_values:(List.map (fun i -> Value.Int i) allowed)
    ?description ?min_value ?max_value Int name

let bool ?default ?description name =
  make
    ?default_value:(Option.map (fun b -> Value.Bool b) default)
    ?description Bool name

let array ?default ?description ?min_length ?max_length name =
  make
    ?default_value:(Option.map (fun values -> Value.Array values) default)
    ?description ?min_length ?max_length Array name

let object_ ?default ?description name =
  make
    ?default_value:(Option.map (fun fields -> Value.Object fields) default)
    ?description Object name

let secure_object ?description name = make ?description Secure_object name
