(** Template outputs. Parameters used in an output's value are added to the
    template like those used by resources. *)

module Type : sig
  type t = String | Int | Bool | Array | Object

  val to_string : t -> string
  (** The ARM type, e.g. ["string"]. *)
end

type t = { name : string; output_type : Type.t; value : Arm_expression.t }

val string : string -> Arm_expression.t -> t
val int : string -> Arm_expression.t -> t
val bool : string -> Arm_expression.t -> t
val array : string -> Arm_expression.t -> t
val object_ : string -> Arm_expression.t -> t
