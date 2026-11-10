(** [Microsoft.Web/serverfarms], an App Service plan.

    {[
      let plan = Server_farm.(build [ name "myplan"; sku S1; os Linux ])
      (* : (Server_farm.t, Server_farm.Error.t) result *)
    ]} *)

module Sku : sig
  type t =
    | F1
    | D1
    | B1
    | B2
    | B3
    | S1
    | S2
    | S3
    | P1v2
    | P2v2
    | P3v2
    | P1v3
    | P2v3
    | P3v3

  val to_string : t -> string

  val tier : t -> string
  (** e.g. ["Free"], ["Standard"], ["PremiumV3"]. *)
end

module Os : sig
  type t = Windows | Linux

  val to_string : t -> string
end

module Error : sig
  type t = Missing_name | Invalid_name of string | Invalid_capacity of int

  val to_string : t -> string
end

type config = {
  name : string option;
  sku : Sku.t;
  os : Os.t;
  capacity : int;
  location : Azf.Arm_expression.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated server farm. *)

val type_name : string
val api_version : string

val default : config
(** No name, [F1], [Windows], one worker, located in the resource group's
    location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 1–60 characters, letters, digits and hyphens. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result.
    [capacity] must be at least 1. *)

val name : string -> config -> config
val sku : Sku.t -> config -> config
val os : Os.t -> config -> config

val capacity : int -> config -> config
(** Number of workers. *)

val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t
val is_linux : t -> bool
val to_arm_resource : t -> Azf.Arm_resource.t
