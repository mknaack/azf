(** Deploys a {!Azf.Deployment.t} to a resource group with the Azure CLI
    ([az deployment group ...]). [az] must be installed and logged in.

    {[
      Azf_deploy.Az_cli.create
        [ resource_group "my-rg"; parameter "DB_PASSWORD" (String password) ]
        deployment
    ]}

    The template and parameter values are written to temporary files that are
    removed afterwards, so secrets never appear on the command line. *)

module Mode : sig
  type t =
    | Incremental  (** Leave resources not in the template alone (default). *)
    | Complete
        (** Delete resources in the group that are not in the template. *)

  val to_string : t -> string
end

module Error : sig
  type t =
    | Missing_resource_group
    | Az_not_found of string  (** The [az] executable that could not be run. *)
    | Failed of { exit_code : int; stderr : string }
        (** [az] ran but failed, e.g. because the template is invalid. *)
    | Unexpected_output of string  (** [az] output that could not be read. *)

  val to_string : t -> string
end

type config = {
  resource_group : string option;
  name : string;
  mode : Mode.t;
  parameters : (string * Azf.Parameter.Value.t) list;
  az : string;
}

val default : config
(** No resource group, deployment name ["azf"], {!Mode.Incremental}, no
    parameter values and executable ["az"]. *)

val resource_group : string -> config -> config

val name : string -> config -> config
(** The deployment name shown in the resource group's deployment history. *)

val mode : Mode.t -> config -> config

val parameter : string -> Azf.Parameter.Value.t -> config -> config
(** A value for a template parameter, e.g. a [securestring] parameter added by
    [Web_app.add_secret_setting]. *)

val az : string -> config -> config
(** The Azure CLI executable to run, if not ["az"] on the [PATH]. *)

val validate :
  (config -> config) list -> Azf.Deployment.t -> (unit, Error.t) result
(** Runs [az deployment group validate]. *)

val what_if :
  (config -> config) list -> Azf.Deployment.t -> (string, Error.t) result
(** Runs [az deployment group what-if] and returns its report of what would
    change. *)

val create :
  (config -> config) list ->
  Azf.Deployment.t ->
  ((string * string) list, Error.t) result
(** Runs [az deployment group create] and returns the template's outputs by
    name. String outputs are returned as is, others as JSON. *)

val create_resource_group :
  (config -> config) list -> location:string -> (unit, Error.t) result
(** Runs [az group create] for the configured resource group. Succeeds if the
    group already exists in the same location. *)
