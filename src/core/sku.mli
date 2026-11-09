(** The SKU block shared by most ARM resources. Only [name] is required; unset
    fields are omitted from the JSON. *)

type t = {
  name : string;
  tier : string option;
  size : string option;
  family : string option;
  capacity : int option;
}

val make :
  ?tier:string -> ?size:string -> ?family:string -> ?capacity:int -> string -> t

val yojson_of_t : t -> Yojson.Safe.t
