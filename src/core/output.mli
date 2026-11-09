(** Template outputs. *)

type output_type = String | Int | Bool
type t = { name : string; output_type : output_type; value : Arm_expression.t }

val string : string -> Arm_expression.t -> t
val int : string -> Arm_expression.t -> t
val bool : string -> Arm_expression.t -> t

val type_name : t -> string
(** The ARM type, e.g. ["string"]. *)
