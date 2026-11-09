(** Template parameters, hoisted into the template's [parameters] block. *)

type param_type = String | Secure_string | Int | Bool

type t = {
  name : string;
  param_type : param_type;
  default_value : Arm_expression.t option;
}

val string : ?default:string -> string -> t
val secure_string : string -> t
val int : ?default:int -> string -> t
val bool : ?default:bool -> string -> t

val to_expression : t -> Arm_expression.t
(** [parameters('name')] *)

val type_name : t -> string
(** The ARM type, e.g. ["securestring"]. *)
