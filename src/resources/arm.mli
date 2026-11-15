(** Farmer's [arm { ... }]: a deployment of validated resources, with a default
    location for them.

    {[
      let deployment =
        let* plan = Server_farm.(build [ name "myplan" ]) in
        let* app = Web_app.(build [ name "myapp"; service_plan plan ]) in
        Arm.(
          build [ location North_europe; add_resource plan; add_resource app ])

      let () = Arm.quick_write "template" deployment
    ]} *)

type config
(** Builder state. Turned into a {!Azf.Deployment.t} by {!build}. *)

val build : (config -> config) list -> (Azf.Deployment.t, Error.t) result
(** Applies the transformers in order. Fails if two resources have the same type
    and name, ignoring case as Azure does. *)

val location : Azf.Location.t -> config -> config
(** Where resources built without a [location] go. Defaults to the resource
    group's location. *)

val add_resource : _ Resource.t -> config -> config
(** Any builder's result, e.g. a {!Web_app.t}. *)

val add_arm_resource : Azf.Arm_resource.t -> config -> config
(** A resource no builder covers. Its location is kept as it is. *)

val add_parameter : Azf.Parameter.t -> config -> config
(** Only needed for parameters no resource or output uses. *)

val add_output : Azf.Output.t -> config -> config

val quick_write : string -> (Azf.Deployment.t, Error.t) result -> unit
(** [quick_write name deployment] writes the template to [name ^ ".json"], like
    Farmer's [Writer.quickWrite]. For scripts: on [Error e] it prints [e] to
    stderr and exits with code 1. *)
