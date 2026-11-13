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
(** Only needed for parameters no resource or output uses. *)

val add_output : Output.t -> t -> t

val schema : string
(** ["https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"]
*)

val to_string : t -> string
(** The ARM template as pretty-printed JSON. Resources, parameters and outputs
    keep the order they were added in. Each resource's [dependsOn] gets its
    {!Arm_resource.t.references} that are also in this deployment. The
    [parameters] block holds the added parameters followed by those used by
    resources and outputs; when two share a name, the first one wins. *)
