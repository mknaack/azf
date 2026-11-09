(** A single entry in a template's [resources] array. Resource builders produce
    these. *)

type t = {
  type_name : string;  (** e.g. ["Microsoft.Storage/storageAccounts"] *)
  api_version : string;
  name : string;
  location : Arm_expression.t option;
  tags : (string * string) list;
  sku : Yojson.Safe.t option;
  kind : string option;
  depends_on : Resource_id.t list;
  properties : Yojson.Safe.t;
}

val resource_id : t -> Resource_id.t

val to_json : t -> Yojson.Safe.t
(** Empty [tags], [dependsOn] and unset options are omitted. *)
