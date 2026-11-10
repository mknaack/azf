(** [Microsoft.Storage/storageAccounts]

    {[
      let storage =
        Storage_account.(build [ name "mystorage"; sku Standard_GRS ])
      (* : (Storage_account.t, Storage_account.Error.t) result *)
    ]} *)

module Sku : sig
  type t =
    | Standard_LRS
    | Standard_GRS
    | Standard_RAGRS
    | Standard_ZRS
    | Standard_GZRS
    | Standard_RAGZRS
    | Premium_LRS
    | Premium_ZRS

  val to_string : t -> string
end

module Kind : sig
  type t =
    | Storage_v2
    | Storage
    | Blob_storage
    | Block_blob_storage
    | File_storage

  val to_string : t -> string
end

module Access_tier : sig
  type t = Hot | Cool

  val to_string : t -> string
end

module Error : sig
  type t = Missing_name | Invalid_name of string

  val to_string : t -> string
end

type config = {
  name : string option;
  sku : Sku.t;
  kind : Kind.t;
  access_tier : Access_tier.t;
  https_only : bool;
  location : Azf.Arm_expression.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated storage account. *)

val type_name : string
val api_version : string

val default : config
(** No name, [Standard_LRS], [Storage_v2], [Hot], HTTPS only, located in the
    resource group's location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 3–24 characters, lowercase letters and digits only. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result. *)

val name : string -> config -> config
val sku : Sku.t -> config -> config
val kind : Kind.t -> config -> config
val access_tier : Access_tier.t -> config -> config
val https_only : bool -> config -> config
val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val connection_string : t -> Azf.Arm_expression.t
(** Connection string built from the account's first key with [listKeys()].
    Anything using it must also {!val-depends_on} the account. *)

val to_arm_resource : t -> Azf.Arm_resource.t
