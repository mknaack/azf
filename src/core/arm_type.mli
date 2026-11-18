(** Type indexes for ARM values with no OCaml counterpart. They have no values;
    they only appear as the ['a] in {!Parameter.t} and {!Arm_expression.t}, e.g.
    [secure_string Arm_expression.t]. Plain strings, ints and bools use
    [string], [int] and [bool]. *)

type secure_string = |
type array_ = |
type object_ = |
type secure_object = |
