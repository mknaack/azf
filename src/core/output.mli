(** Template outputs. Parameters used in an output's value are added to the
    template like those used by resources.

    There are no secure outputs: output values are stored in the deployment
    history, so a [secure_string] expression is rejected at compile time. *)

module Type : sig
  type t = String | Int | Bool | Array | Object

  val to_string : t -> string
  (** The ARM type, e.g. ["string"]. *)
end

type t = private {
  name : string;
  output_type : Type.t;
  value : Arm_expression.any;
}

val string : string -> string Arm_expression.t -> t
val int : string -> int Arm_expression.t -> t
val bool : string -> bool Arm_expression.t -> t
val array : string -> Arm_type.array_ Arm_expression.t -> t
val object_ : string -> Arm_type.object_ Arm_expression.t -> t
