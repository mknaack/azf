(** ARM template expressions, serialized to ["[...]"] strings.

    An ['a t] evaluates to an ARM value of type ['a]: [string], [int], [bool] or
    one of the {!Arm_type} indexes. Literals, parameters and resource IDs have
    their type fixed; [Variables], [Property] and [Call] can't be checked, so
    their type is chosen by the caller, e.g.
    [(Property (Reference id, "primaryKey") : Arm_type.secure_string t)]. *)

type _ t =
  | String : string -> string t  (** Literal string. *)
  | Int : int -> int t
  | Bool : bool -> bool t
  | Parameter : 'a Parameter.t -> 'a t  (** [parameters('name')] *)
  | Variables : string -> 'a t  (** [variables('name')] *)
  | Concat : string t list -> string t  (** [concat(a, b, ...)] *)
  | Resource_id : Resource_id.t -> string t  (** [resourceId('type', 'name')] *)
  | Reference : Resource_id.t -> Arm_type.object_ t
      (** [reference(resourceId('type', 'name'))] *)
  | Property : _ t * string -> 'a t  (** [expr.property] *)
  | Call : string * any list -> 'a t  (** Any other template function. *)

and any = Any : _ t -> any  (** An expression of any type. *)

val resource_ids : _ t -> Resource_id.t list
(** Every resource referenced by [Resource_id] or [Reference], in order, without
    duplicates. *)

val parameters : _ t -> Parameter.any list
(** Every parameter used, in order, without duplicate names. *)

val resource_group_location : string t
(** [resourceGroup().location] *)

val to_string : _ t -> string
(** Template string form. Literal strings are returned as-is, with a leading
    bracket doubled so ARM does not parse them as expressions; everything else
    is wrapped in brackets, e.g.
    [{|"[resourceId('Microsoft.Web/sites', 'myapp')]"|}]. *)

val yojson_of_t : _ t -> Yojson.Safe.t
(** Literal [Int] and [Bool] become JSON numbers/booleans; everything else is a
    JSON string as produced by {!to_string}. *)

val yojson_of_any : any -> Yojson.Safe.t
