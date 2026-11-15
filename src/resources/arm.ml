open Azf

type config = {
  location : Location.t option;
  resources : (location:Arm_expression.t -> Arm_resource.t list) list;
  parameters : Parameter.t list;
  outputs : Output.t list;
}

let default = { location = None; resources = []; parameters = []; outputs = [] }
let location location c = { c with location = Some location }
let add_emit emit c = { c with resources = c.resources @ [ emit ] }

let add_resource r =
  add_emit (fun ~location -> Resource.to_arm_resources ~location r)

let add_arm_resource r = add_emit (fun ~location:_ -> [ r ])
let add_parameter p c = { c with parameters = c.parameters @ [ p ] }
let add_output o c = { c with outputs = c.outputs @ [ o ] }

let is_expression name =
  String.starts_with ~prefix:"[" name
  && not (String.starts_with ~prefix:"[[" name)

(* ARM resource types and literal names are case-insensitive. A name expression
   can't be evaluated here, so it only matches the same expression. *)
let same_resource a b =
  let lower = String.lowercase_ascii in
  let name_a = Resource_id.name a and name_b = Resource_id.name b in
  lower (Resource_id.type_name a) = lower (Resource_id.type_name b)
  &&
  if is_expression name_a || is_expression name_b then name_a = name_b
  else lower name_a = lower name_b

let rec first_duplicate = function
  | [] -> None
  | id :: rest when List.exists (same_resource id) rest -> Some id
  | _ :: rest -> first_duplicate rest

let build transformers =
  let c = List.fold_left (fun c f -> f c) default transformers in
  let location =
    Option.fold ~none:Arm_expression.resource_group_location
      ~some:Location.to_expression c.location
  in
  let resources = List.concat_map (fun emit -> emit ~location) c.resources in
  match first_duplicate (List.map Arm_resource.resource_id resources) with
  | Some id -> Error (Error.Arm (Duplicate_resource id))
  | None ->
      Ok
        (Deployment.build
           (Deployment.add_resources resources
            :: List.map Deployment.add_parameter c.parameters
           @ List.map Deployment.add_output c.outputs))

let quick_write name = function
  | Ok deployment -> Deployment.write_file (name ^ ".json") deployment
  | Error e ->
      prerr_endline (Error.to_string e);
      exit 1
