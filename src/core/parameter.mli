(** Template parameters. Any parameter used in a resource or output expression
    (through {!Arm_expression.t.Parameter}) is added to the template's
    [parameters] block, so it rarely needs adding to a deployment by hand. *)

module Value : sig
  (** Literal values for defaults and allowed values. *)
  type t =
    | String of string
    | Int of int
    | Bool of bool
    | Array of t list
    | Object of (string * t) list

  val yojson_of_t : t -> Yojson.Safe.t
end

module Type : sig
  type t =
    | String
    | Secure_string
    | Int
    | Bool
    | Array
    | Object
    | Secure_object

  val to_string : t -> string
  (** The ARM type, e.g. ["securestring"]. *)
end

type t = {
  name : string;
  param_type : Type.t;
  default_value : Value.t option;
  allowed_values : Value.t list;
  description : string option;
  min_value : int option;
  max_value : int option;
  min_length : int option;
  max_length : int option;
}

val string :
  ?default:string ->
  ?allowed:string list ->
  ?description:string ->
  ?min_length:int ->
  ?max_length:int ->
  string ->
  t

val secure_string :
  ?description:string -> ?min_length:int -> ?max_length:int -> string -> t

val int :
  ?default:int ->
  ?allowed:int list ->
  ?description:string ->
  ?min_value:int ->
  ?max_value:int ->
  string ->
  t

val bool : ?default:bool -> ?description:string -> string -> t

val array :
  ?default:Value.t list ->
  ?description:string ->
  ?min_length:int ->
  ?max_length:int ->
  string ->
  t

val object_ :
  ?default:(string * Value.t) list -> ?description:string -> string -> t

val secure_object : ?description:string -> string -> t
