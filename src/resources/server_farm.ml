open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

module Sku = struct
  type t =
    | F1
    | D1
    | B1
    | B2
    | B3
    | S1
    | S2
    | S3
    | P1v2
    | P2v2
    | P3v2
    | P1v3
    | P2v3
    | P3v3

  let to_string = function
    | F1 -> "F1"
    | D1 -> "D1"
    | B1 -> "B1"
    | B2 -> "B2"
    | B3 -> "B3"
    | S1 -> "S1"
    | S2 -> "S2"
    | S3 -> "S3"
    | P1v2 -> "P1v2"
    | P2v2 -> "P2v2"
    | P3v2 -> "P3v2"
    | P1v3 -> "P1v3"
    | P2v3 -> "P2v3"
    | P3v3 -> "P3v3"

  let tier = function
    | F1 -> "Free"
    | D1 -> "Shared"
    | B1 | B2 | B3 -> "Basic"
    | S1 | S2 | S3 -> "Standard"
    | P1v2 | P2v2 | P3v2 -> "PremiumV2"
    | P1v3 | P2v3 | P3v3 -> "PremiumV3"
end

module Os = struct
  type t = Windows | Linux

  let to_string = function Windows -> "Windows" | Linux -> "Linux"
end

module Error = struct
  type t = Missing_name | Invalid_name of string | Invalid_capacity of int

  let to_string = function
    | Missing_name -> "Server farm name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid server farm name %S: must be 1-60 characters, letters, \
           digits and hyphens only"
          name
    | Invalid_capacity n ->
        Printf.sprintf "Invalid server farm capacity %d: must be at least 1" n
end

type config = {
  name : string option;
  sku : Sku.t;
  os : Os.t;
  capacity : int;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = { farm_name : string; config : config }

let type_name = "Microsoft.Web/serverfarms"
let api_version = "2022-09-01"

let default =
  {
    name = None;
    sku = Sku.F1;
    os = Os.Windows;
    capacity = 1;
    location = Arm_expression.resource_group_location;
    tags = [];
    depends_on = [];
  }

let is_name_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' -> true
  | _ -> false

let validate_name name =
  let length = String.length name in
  if length >= 1 && length <= 60 && String.for_all is_name_char name then
    Ok name
  else Error (Error.Invalid_name name)

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  match config.name with
  | None -> Error Error.Missing_name
  | Some _ when config.capacity < 1 ->
      Error (Error.Invalid_capacity config.capacity)
  | Some name ->
      Result.map (fun farm_name -> { farm_name; config }) (validate_name name)

let name name c = { c with name = Some name }
let sku sku c = { c with sku }
let os os c = { c with os }
let capacity capacity c = { c with capacity }
let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id t = Resource_id.make ~type_name t.farm_name
let is_linux t = t.config.os = Os.Linux

type properties = { reserved : bool } [@@deriving yojson_of]

let to_arm_resource { farm_name; config = c } : Arm_resource.t =
  {
    type_name;
    api_version;
    name = farm_name;
    location = Some c.location;
    tags = c.tags;
    sku =
      Some
        (Azf.Sku.make ~tier:(Sku.tier c.sku) ~capacity:c.capacity
           (Sku.to_string c.sku));
    kind = Some (match c.os with Os.Windows -> "app" | Os.Linux -> "linux");
    depends_on = c.depends_on;
    properties = yojson_of_properties { reserved = c.os = Os.Linux };
  }
