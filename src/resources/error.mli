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
  type t =
    | Missing_name
    | Invalid_name of string
    | Invalid_retention of int
    | Invalid_daily_cap of float

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

type t =
  | Storage_account of Storage_account.t
  | Server_farm of Server_farm.t
  | Web_app of Web_app.t
  | Log_analytics of Log_analytics.t
  | App_insights of App_insights.t

val to_string : t -> string
