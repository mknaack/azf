(** Errors from every resource builder, so builders combine with [let*]:

    {[
      let* storage = Storage_account.(build [ name "mystorage" ]) in
      let* plan = Server_farm.(build [ name "myplan" ]) in
      ...
    ]} *)

module Storage_account : sig
  type t = Missing_name | Invalid_name of string

  val to_string : t -> string
end

module Server_farm : sig
  type t = Missing_name | Invalid_name of string | Invalid_capacity of int

  val to_string : t -> string
end

module Web_app : sig
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_service_plan
    | Python_requires_linux of string
        (** A Python runtime (with this version) on a Windows plan. *)

  val to_string : t -> string
end

module Log_analytics : sig
  type t = Missing_name | Invalid_name of string | Invalid_retention of int

  val to_string : t -> string
end

module App_insights : sig
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_workspace
    | Invalid_sampling_percentage of float

  val to_string : t -> string
end

module Cosmos_db : sig
  type t =
    | Missing_name
    | Invalid_name of string
    | Invalid_bounded_staleness of {
        max_staleness_prefix : int;
        max_interval_seconds : int;
      }
    | Duplicate_database of string
    | Throughput_on_serverless of string
    | Missing_database_name
    | Invalid_database_name of string
    | Invalid_provisioned_throughput of int
    | Invalid_autoscale_throughput of int
    | Duplicate_container of string
    | Missing_container_name
    | Invalid_container_name of string
    | Missing_partition_key of string
    | Invalid_partition_key of string list
    | Invalid_default_ttl of int

  val to_string : t -> string
end

type t =
  | Storage_account of Storage_account.t
  | Server_farm of Server_farm.t
  | Web_app of Web_app.t
  | Log_analytics of Log_analytics.t
  | App_insights of App_insights.t
  | Cosmos_db of Cosmos_db.t

val to_string : t -> string
