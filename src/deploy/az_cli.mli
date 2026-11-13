(** Deploys a {!Azf.Deployment.t} to a resource group with the Azure CLI
    ([az deployment group ...]). [az] must be installed and logged in.

    {[
      let config =
        Azf_deploy.Az_cli.Config.(
          build ~az:"az" ~resource_group:"my-rg" ~name:"my-deployment"
            [ parameter "DB_PASSWORD" (String password) ])
      in
      Azf_deploy.Az_cli.create config deployment
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
    | Az_not_found of string  (** The [az] executable that could not be run. *)
    | Failed of { exit_code : int; stderr : string }
        (** [az] ran but failed, e.g. because the template is invalid. *)
    | Unexpected_output of string  (** [az] output that could not be read. *)

  val to_string : t -> string
end

module Config : sig
  type t = {
    az : string;  (** The Azure CLI executable, e.g. ["az"]. *)
    resource_group : string;
    name : string;
        (** The deployment name shown in the resource group's deployment
            history. *)
    mode : Mode.t;
    parameters : (string * Azf.Parameter.Value.t) list;
  }

  val build :
    az:string -> resource_group:string -> name:string -> (t -> t) list -> t
  (** Starts from {!Mode.Incremental} and no parameter values, then applies the
      transformers in order. *)

  val mode : Mode.t -> t -> t

  val parameter : string -> Azf.Parameter.Value.t -> t -> t
  (** A value for a template parameter, e.g. a [securestring] parameter added by
      [Web_app.add_secret_setting]. *)
end

val validate : Config.t -> Azf.Deployment.t -> (unit, Error.t) result
(** Runs [az deployment group validate]. *)

val what_if : Config.t -> Azf.Deployment.t -> (string, Error.t) result
(** Runs [az deployment group what-if] and returns its report of what would
    change. *)

val create :
  Config.t -> Azf.Deployment.t -> ((string * string) list, Error.t) result
(** Runs [az deployment group create] and returns the template's outputs by
    name. String outputs are returned as is, others as JSON. *)

val create_resource_group :
  Config.t -> location:string -> (unit, Error.t) result
(** Runs [az group create] for the config's resource group. Succeeds if the
    group already exists in the same location. *)
