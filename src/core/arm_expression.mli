(** ARM template expressions, serialized to ["[...]"] strings. *)

type t =
  | String of string  (** Literal string. *)
  | Int of int
  | Bool of bool
  | Parameter of Parameter.t  (** [parameters('name')] *)
  | Variables of string  (** [variables('name')] *)
  | Concat of t list  (** [concat(a, b, ...)] *)
  | Resource_id of Resource_id.t  (** [resourceId('type', 'name')] *)
  | Reference of Resource_id.t  (** [reference(resourceId('type', 'name'))] *)
  | Property of t * string  (** [expr.property] *)
  | Call of string * t list  (** Any other template function. *)

val resource_ids : t -> Resource_id.t list
(** Every resource referenced by [Resource_id] or [Reference], in order, without
    duplicates. *)

val parameters : t -> Parameter.t list
(** Every parameter used, in order, without duplicate names. *)

val resource_group_location : t
(** [resourceGroup().location] *)

val to_string : t -> string
(** Template string form. Literal strings are returned as-is, with a leading
    bracket doubled so ARM does not parse them as expressions; everything else
    is wrapped in brackets, e.g.
    [{|"[resourceId('Microsoft.Web/sites', 'myapp')]"|}]. *)

val yojson_of_t : t -> Yojson.Safe.t
(** Literal [Int] and [Bool] become JSON numbers/booleans; everything else is a
    JSON string as produced by {!to_string}. *)
