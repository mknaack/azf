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
  type _ t =
    | String : string t
    | Secure_string : Arm_type.secure_string t
    | Int : int t
    | Bool : bool t
    | Array : Arm_type.array_ t
    | Object : Arm_type.object_ t
    | Secure_object : Arm_type.secure_object t

  val to_string : _ t -> string
  (** The ARM type, e.g. ["securestring"]. *)
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
(** A parameter whose values have type ['a], e.g. [string t] or
    [Arm_type.secure_string t]. *)

type any = Any : _ t -> any  (** A parameter of any type. *)

val name : any -> string

val string :
  ?default:string ->
  ?allowed:string list ->
  ?description:string ->
  ?min_length:int ->
  ?max_length:int ->
  string ->
  string t

val secure_string :
  ?description:string ->
  ?min_length:int ->
  ?max_length:int ->
  string ->
  Arm_type.secure_string t

val int :
  ?default:int ->
  ?allowed:int list ->
  ?description:string ->
  ?min_value:int ->
  ?max_value:int ->
  string ->
  int t

val bool : ?default:bool -> ?description:string -> string -> bool t

val array :
  ?default:Value.t list ->
  ?description:string ->
  ?min_length:int ->
  ?max_length:int ->
  string ->
  Arm_type.array_ t

val object_ :
  ?default:(string * Value.t) list ->
  ?description:string ->
  string ->
  Arm_type.object_ t

val secure_object : ?description:string -> string -> Arm_type.secure_object t
