type _ t =
  | String : string -> string t
  | Int : int -> int t
  | Bool : bool -> bool t
  | Parameter : 'a Parameter.t -> 'a t
  | Variables : string -> 'a t
  | Concat : string t list -> string t
  | Resource_id : Resource_id.t -> string t
  | Reference : Resource_id.t -> Arm_type.object_ t
  | Property : _ t * string -> 'a t
  | Call : string * any list -> 'a t

and any = Any : _ t -> any

let resource_ids e =
  let add ids id =
    if List.exists (Resource_id.equal id) ids then ids else id :: ids
  in
  let rec collect : type a. Resource_id.t list -> a t -> Resource_id.t list =
   fun ids -> function
     | String _ | Int _ | Bool _ | Parameter _ | Variables _ -> ids
     | Resource_id id | Reference id -> add ids id
     | Property (e, _) -> collect ids e
     | Concat es -> List.fold_left collect ids es
     | Call (_, es) -> List.fold_left (fun ids (Any e) -> collect ids e) ids es
  in
  List.rev (collect [] e)

let parameters e =
  let add params p =
    let name = Parameter.name p in
    if List.exists (fun q -> String.equal name (Parameter.name q)) params then
      params
    else p :: params
  in
  let rec collect : type a. Parameter.any list -> a t -> Parameter.any list =
   fun params -> function
     | String _ | Int _ | Bool _ | Variables _ | Resource_id _ | Reference _ ->
         params
     | Parameter p -> add params (Parameter.Any p)
     | Property (e, _) -> collect params e
     | Concat es -> List.fold_left collect params es
     | Call (_, es) ->
         List.fold_left (fun params (Any e) -> collect params e) params es
  in
  List.rev (collect [] e)

let resource_group_location = Property (Call ("resourceGroup", []), "location")
let quote s = "'" ^ String.concat "''" (String.split_on_char '\'' s) ^ "'"
let call name args = name ^ "(" ^ String.concat ", " args ^ ")"

let resource_id_call id =
  call "resourceId"
    [ quote (Resource_id.type_name id); quote (Resource_id.name id) ]

let rec inner : type a. a t -> string = function
  | String s -> quote s
  | Int i -> string_of_int i
  | Bool b -> call (string_of_bool b) []
  | Parameter p -> call "parameters" [ quote p.name ]
  | Variables name -> call "variables" [ quote name ]
  | Concat parts -> call "concat" (List.map inner parts)
  | Resource_id id -> resource_id_call id
  | Reference id -> call "reference" [ resource_id_call id ]
  | Property (e, prop) -> inner e ^ "." ^ prop
  | Call (name, args) -> call name (List.map (fun (Any e) -> inner e) args)

let to_string : type a. a t -> string = function
  | String s when String.length s > 0 && s.[0] = '[' -> "[" ^ s
  | String s -> s
  | e -> "[" ^ inner e ^ "]"

let yojson_of_t : type a. a t -> Yojson.Safe.t = function
  | Int i -> `Int i
  | Bool b -> `Bool b
  | e -> `String (to_string e)

let yojson_of_any (Any e) = yojson_of_t e
