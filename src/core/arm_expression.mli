(** ARM template expressions, serialized to ["[...]"] strings. *)

type t =
  | String of string  (** Literal string. *)
  | Int of int
  | Bool of bool
  | Parameters of string  (** [parameters('name')] *)
  | Variables of string  (** [variables('name')] *)
  | Concat of t list  (** [concat(a, b, ...)] *)
  | Resource_id of Resource_id.t  (** [resourceId('type', 'name')] *)
  | Reference of Resource_id.t  (** [reference(resourceId('type', 'name'))] *)
  | Property of t * string  (** [expr.property] *)
  | Call of string * t list  (** Any other template function. *)

val resource_group_location : t
(** [resourceGroup().location] *)

val to_string : t -> string
(** Template string form. Literal strings are returned as-is (a leading ['['] is
    escaped as ["[["]); everything else is wrapped in brackets, e.g.
    ["[resourceId('Microsoft.Web/sites', 'myapp')]"]. *)

val to_json : t -> Yojson.Safe.t
(** Literal [Int] and [Bool] become JSON numbers/booleans; everything else is a
    JSON string as produced by {!to_string}. *)
