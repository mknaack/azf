(** [Microsoft.DocumentDB/databaseAccounts] for the NoSQL (SQL) API, with its
    [sqlDatabases] and [sqlDatabases/containers] child resources.

    {[
      let* orders =
        Cosmos_db.Container.(
          build [ name "orders"; partition_key [ "/customerId" ] ])
      in
      let* db =
        Cosmos_db.Database.(
          build [ name "shop"; throughput (Autoscale 1000); add_container orders ])
      in
      let* cosmos =
        Cosmos_db.(build [ name "mycosmos"; consistency Session; add_database db ])
      in
      ...
      Deployment.add_resources (Cosmos_db.to_arm_resources cosmos)
    ]}

    Each database records the account, and each container its database, as an
    {!Azf.Arm_resource.t.references}, so {!Azf.Deployment.to_string} orders them
    with [dependsOn]. The account has a single region, its [location]. *)

module Consistency : sig
  type t =
    | Eventual
    | Consistent_prefix
    | Session
    | Bounded_staleness of {
        max_staleness_prefix : int;
        max_interval_seconds : int;
      }
        (** Reads lag writes by at most [max_staleness_prefix] (at least 10)
            versions or [max_interval_seconds] (5–86400). *)
    | Strong

  val to_string : t -> string
end

module Capacity_mode : sig
  type t =
    | Provisioned
    | Serverless  (** Pay per request; databases cannot set {!Throughput.t}. *)
end

module Throughput : sig
  type t =
    | Provisioned of int
        (** Fixed RU/s shared by the database's containers: at least 400, a
            multiple of 100. *)
    | Autoscale of int
        (** Maximum RU/s, scaling down to 10% of it: at least 1000, a multiple
            of 1000. *)
end

module Container : sig
  type config = {
    name : string option;
    partition_key : string list;
    default_ttl : int option;
  }

  type t
  (** A validated container. *)

  val default : config

  val build : (config -> config) list -> (t, Error.t) result
  (** Requires a name (1–255 characters, without [/ \ # ?], not ending with a
      space) and a partition key. *)

  val name : string -> config -> config

  val partition_key : string list -> config -> config
  (** One path, e.g. [[ "/customerId" ]], or two to three paths for a
      hierarchical key, e.g. [[ "/tenantId"; "/userId" ]]. Each path starts with
      [/]. *)

  val default_ttl : int -> config -> config
  (** Seconds until items expire, or [-1] to enable per-item TTL with no
      default. *)
end

module Database : sig
  type config = {
    name : string option;
    throughput : Throughput.t option;
    containers : Container.t list;
  }

  type t
  (** A validated SQL database. *)

  val default : config

  val build : (config -> config) list -> (t, Error.t) result
  (** Requires a name (same rules as {!Container.build}); container names must
      be unique. *)

  val name : string -> config -> config
  val throughput : Throughput.t -> config -> config
  val add_container : Container.t -> config -> config
end

type config = {
  name : string option;
  consistency : Consistency.t;
  capacity_mode : Capacity_mode.t;
  free_tier : bool;
  databases : Database.t list;
  location : Azf.Arm_expression.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated Cosmos DB account. *)

val type_name : string
val database_type_name : string
val container_type_name : string
val api_version : string

val default : config
(** No name or databases, [Session] consistency, provisioned capacity, no free
    tier, located in the resource group's location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 3–44 characters, lowercase letters, digits and hyphens, not
    starting or ending with a hyphen. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result.
    Database names must be unique, and a serverless account's databases cannot
    set throughput. *)

val name : string -> config -> config
val consistency : Consistency.t -> config -> config
val capacity_mode : Capacity_mode.t -> config -> config

val free_tier : bool -> config -> config
(** One free-tier account is allowed per subscription. *)

val add_database : Database.t -> config -> config
val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val endpoint : t -> Azf.Arm_expression.t
(** [reference(...).documentEndpoint], e.g.
    ["https://mycosmos.documents.azure.com:443/"]. *)

val primary_key : t -> Azf.Arm_expression.t
(** The primary master key, via [listKeys()]. *)

val connection_string : t -> Azf.Arm_expression.t
(** The primary connection string, via [listConnectionStrings()]. *)

val to_arm_resources : t -> Azf.Arm_resource.t list
(** The account followed by each database and its containers. *)
