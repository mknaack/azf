(** Template outputs. *)

type output_type = String | Int | Bool
type t = { name : string; output_type : output_type; value : Arm_expression.t }

val string : string -> Arm_expression.t -> t
val int : string -> Arm_expression.t -> t
val bool : string -> Arm_expression.t -> t

val to_definition : t -> string * Yojson.Safe.t
(** Name and definition for the template's [outputs] object. *)
