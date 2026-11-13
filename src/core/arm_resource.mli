(** A single entry in a template's [resources] array. Resource builders produce
    these. *)

type t = {
  type_name : string;  (** e.g. ["Microsoft.Storage/storageAccounts"] *)
  api_version : string;
  name : string;
  location : Arm_expression.t option;
  tags : (string * string) list;
  sku : Sku.t option;
  kind : string option;
  depends_on : Resource_id.t list;  (** Emitted as-is. *)
  references : Resource_id.t list;
      (** Resources used in this resource's expressions. Not emitted;
          {!Deployment.to_string} adds the ones in the same deployment to
          [dependsOn]. *)
  parameters : Parameter.t list;
      (** Parameters used in this resource's expressions. Not emitted;
          {!Deployment.to_string} adds them to the template. *)
  properties : Yojson.Safe.t;
}

val resource_id : t -> Resource_id.t

val yojson_of_t : t -> Yojson.Safe.t
(** Empty [tags], [dependsOn] and unset options are omitted. *)

val to_string : t -> string
(** {!yojson_of_t} as pretty-printed JSON. *)
