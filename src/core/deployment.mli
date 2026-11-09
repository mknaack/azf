(** A deployment: resources, parameters and outputs, emitted as an ARM template.
*)

type t = {
  resources : Arm_resource.t list;
  parameters : Parameter.t list;
  outputs : Output.t list;
}

val empty : t

val build : (t -> t) list -> t
(** Applies the transformers to {!empty} in order. *)

val add_resource : Arm_resource.t -> t -> t
val add_resources : Arm_resource.t list -> t -> t
val add_parameter : Parameter.t -> t -> t
val add_output : Output.t -> t -> t

val schema : string
(** ["https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"]
*)

val emit : t -> Yojson.Safe.t
(** The ARM template. Resources, parameters and outputs keep the order they were
    added in. *)
