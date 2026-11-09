(** [Microsoft.Storage/storageAccounts]

    {[
      let storage =
        Storage_account.(build [ name "mystorage"; sku Standard_GRS ])
      (* : (Storage_account.t, Storage_account.error) result *)
    ]} *)

type sku =
  | Standard_LRS
  | Standard_GRS
  | Standard_RAGRS
  | Standard_ZRS
  | Standard_GZRS
  | Standard_RAGZRS
  | Premium_LRS
  | Premium_ZRS

type kind =
  | Storage_v2
  | Storage
  | Blob_storage
  | Block_blob_storage
  | File_storage

type access_tier = Hot | Cool

type config = {
  name : string option;
  sku : sku;
  kind : kind;
  access_tier : access_tier;
  https_only : bool;
  location : Azf.Arm_expression.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated storage account. *)

type error = Missing_name | Invalid_name of string

val string_of_error : error -> string
val type_name : string
val api_version : string

val default : config
(** No name, [Standard_LRS], [Storage_v2], [Hot], HTTPS only, located in the
    resource group's location. *)

val validate_name : string -> (string, error) result
(** Azure's rule: 3–24 characters, lowercase letters and digits only. *)

val build : (config -> config) list -> (t, error) result
(** Applies the transformers to {!default} in order and validates the result. *)

val name : string -> config -> config
val sku : sku -> config -> config
val kind : kind -> config -> config
val access_tier : access_tier -> config -> config
val https_only : bool -> config -> config
val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t
val to_arm_resource : t -> Azf.Arm_resource.t
