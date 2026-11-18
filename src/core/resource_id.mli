(** Typed reference to an ARM resource, used for [dependsOn] and [resourceId()]
    expressions instead of raw strings. *)

type t

val make : type_name:string -> string -> t
(** [make ~type_name name], e.g.
    [make ~type_name:"Microsoft.Storage/storageAccounts" "mystorage"]. Child
    resources use the full ["parent/child"] name, which becomes one
    [resourceId()] argument per segment. *)

val type_name : t -> string
val name : t -> string
val equal : t -> t -> bool
