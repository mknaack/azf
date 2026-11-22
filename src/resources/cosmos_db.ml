open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

let ( let* ) = Result.bind
let error e = Error (Error.Cosmos_db e)

let rec find_duplicate = function
  | [] -> None
  | x :: rest -> if List.mem x rest then Some x else find_duplicate rest

let no_duplicates make names =
  match find_duplicate names with None -> Ok () | Some n -> error (make n)

let is_invalid_id_char = function '/' | '\\' | '#' | '?' -> true | _ -> false
let id_length_is_ok id = String.length id >= 1 && String.length id <= 255
let has_no_invalid_id_chars id = not (String.exists is_invalid_id_char id)
let does_not_end_with_space id = not (String.ends_with ~suffix:" " id)

let valid_id id =
  id_length_is_ok id && has_no_invalid_id_chars id && does_not_end_with_space id

module Consistency = struct
  type t =
    | Eventual
    | Consistent_prefix
    | Session
    | Bounded_staleness of {
        max_staleness_prefix : int;
        max_interval_seconds : int;
      }
    | Strong

  let to_string = function
    | Eventual -> "Eventual"
    | Consistent_prefix -> "ConsistentPrefix"
    | Session -> "Session"
    | Bounded_staleness _ -> "BoundedStaleness"
    | Strong -> "Strong"

  let validate = function
    | Bounded_staleness { max_staleness_prefix = p; max_interval_seconds = s }
      when p < 10 || s < 5 || s > 86400 ->
        error
          (Invalid_bounded_staleness
             { max_staleness_prefix = p; max_interval_seconds = s })
    | _ -> Ok ()

  type policy = {
    default_consistency_level : string; [@key "defaultConsistencyLevel"]
    max_staleness_prefix : int option;
        [@key "maxStalenessPrefix"] [@yojson.option]
    max_interval_in_seconds : int option;
        [@key "maxIntervalInSeconds"] [@yojson.option]
  }
  [@@deriving yojson_of]

  let policy t =
    let level = to_string t in
    match t with
    | Bounded_staleness { max_staleness_prefix; max_interval_seconds } ->
        {
          default_consistency_level = level;
          max_staleness_prefix = Some max_staleness_prefix;
          max_interval_in_seconds = Some max_interval_seconds;
        }
    | _ ->
        {
          default_consistency_level = level;
          max_staleness_prefix = None;
          max_interval_in_seconds = None;
        }
end

module Capacity_mode = struct
  type t = Provisioned | Serverless
end

module Throughput = struct
  type t = Provisioned of int | Autoscale of int

  let validate = function
    | Provisioned ru when ru < 400 || ru mod 100 <> 0 ->
        error (Invalid_provisioned_throughput ru)
    | Autoscale ru when ru < 1000 || ru mod 1000 <> 0 ->
        error (Invalid_autoscale_throughput ru)
    | _ -> Ok ()

  type autoscale = { max_throughput : int [@key "maxThroughput"] }
  [@@deriving yojson_of]

  type options = {
    throughput : int option; [@yojson.option]
    autoscale_settings : autoscale option;
        [@key "autoscaleSettings"] [@yojson.option]
  }
  [@@deriving yojson_of]

  let options = function
    | Provisioned ru -> { throughput = Some ru; autoscale_settings = None }
    | Autoscale max_throughput ->
        { throughput = None; autoscale_settings = Some { max_throughput } }
end

module Container = struct
  type config = {
    name : string option;
    partition_key : string list;
    default_ttl : int option;
    throughput : Throughput.t option;
  }

  type t = { container_name : string; config : config }

  let default =
    { name = None; partition_key = []; default_ttl = None; throughput = None }

  let validate_partition_key name paths =
    let valid_path p = String.length p > 1 && p.[0] = '/' in
    match paths with
    | [] -> error (Missing_partition_key name)
    | _ when List.length paths > 3 || not (List.for_all valid_path paths) ->
        error (Invalid_partition_key paths)
    | _ -> Ok ()

  let validate_ttl = function
    | Some ttl when ttl <> -1 && ttl < 1 -> error (Invalid_default_ttl ttl)
    | _ -> Ok ()

  let build transformers =
    let config = List.fold_left (fun c f -> f c) default transformers in
    let* container_name =
      Option.to_result ~none:(Error.Cosmos_db Missing_container_name)
        config.name
    in
    let* () =
      if valid_id container_name then Ok ()
      else error (Invalid_container_name container_name)
    in
    let* () = validate_partition_key container_name config.partition_key in
    let* () = validate_ttl config.default_ttl in
    let* () =
      Option.fold ~none:(Ok ()) ~some:Throughput.validate config.throughput
    in
    Ok { container_name; config }

  let name name c = { c with name = Some name }
  let partition_key paths c = { c with partition_key = paths }
  let default_ttl seconds c = { c with default_ttl = Some seconds }

  let throughput throughput (c : config) =
    { c with throughput = Some throughput }
end

module Database = struct
  type config = {
    name : string option;
    throughput : Throughput.t option;
    containers : Container.t list;
  }

  type t = { database_name : string; config : config }

  let default = { name = None; throughput = None; containers = [] }

  let build transformers =
    let config = List.fold_left (fun c f -> f c) default transformers in
    let* database_name =
      Option.to_result ~none:(Error.Cosmos_db Missing_database_name) config.name
    in
    let* () =
      if valid_id database_name then Ok ()
      else error (Invalid_database_name database_name)
    in
    let* () =
      Option.fold ~none:(Ok ()) ~some:Throughput.validate config.throughput
    in
    let* () =
      no_duplicates
        (fun n -> Error.Cosmos_db.Duplicate_container n)
        (List.map (fun (c : Container.t) -> c.container_name) config.containers)
    in
    Ok { database_name; config }

  let name name c = { c with name = Some name }
  let throughput throughput c = { c with throughput = Some throughput }

  let add_container container c =
    { c with containers = c.containers @ [ container ] }
end

type config = {
  name : string option;
  consistency : Consistency.t;
  capacity_mode : Capacity_mode.t;
  free_tier : bool;
  databases : Database.t list;
  location : Location.t option;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type state = { account_name : string; config : config }
type t = state Resource.t

let type_name = "Microsoft.DocumentDB/databaseAccounts"
let database_type_name = type_name ^ "/sqlDatabases"
let container_type_name = database_type_name ^ "/containers"
let api_version = "2025-04-15"

let default =
  {
    name = None;
    consistency = Consistency.Session;
    capacity_mode = Capacity_mode.Provisioned;
    free_tier = false;
    databases = [];
    location = None;
    tags = [];
    depends_on = [];
  }

let is_name_char = function 'a' .. 'z' | '0' .. '9' | '-' -> true | _ -> false
let name_length_is_ok name = String.length name >= 3 && String.length name <= 44
let has_only_name_chars name = String.for_all is_name_char name

let does_not_start_or_end_with_hyphen name =
  not (String.starts_with ~prefix:"-" name || String.ends_with ~suffix:"-" name)

let validate_name name =
  if
    name_length_is_ok name && has_only_name_chars name
    && does_not_start_or_end_with_hyphen name
  then Ok name
  else error (Invalid_name name)

let provisioned_names (db : Database.t) =
  let containers =
    List.filter_map
      (fun (c : Container.t) ->
        Option.map
          (fun _ -> db.database_name ^ "/" ^ c.container_name)
          c.config.throughput)
      db.config.containers
  in
  Option.fold ~none:containers
    ~some:(fun _ -> db.database_name :: containers)
    db.config.throughput

let check_serverless (c : config) =
  match (c.capacity_mode, List.concat_map provisioned_names c.databases) with
  | Serverless, name :: _ -> error (Throughput_on_serverless name)
  | _ -> Ok ()

let name name c = { c with name = Some name }
let consistency consistency c = { c with consistency }
let capacity_mode capacity_mode c = { c with capacity_mode }
let free_tier free_tier c = { c with free_tier }
let add_database db c = { c with databases = c.databases @ [ db ] }
let location location c = { c with location = Some location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let state_resource_id state = Resource_id.make ~type_name state.account_name
let resource_id t = state_resource_id (Resource.state t)

let endpoint t =
  Arm_expression.Property (Reference (resource_id t), "documentEndpoint")

let list_call name t =
  Arm_expression.Call (name, [ Resource_id (resource_id t); String api_version ])

let primary_key t =
  Arm_expression.Property (list_call "listKeys" t, "primaryMasterKey")

let connection_string t =
  Arm_expression.Property
    ( list_call "listConnectionStrings" t,
      "connectionStrings[0].connectionString" )

type location = {
  location_name : Arm_expression.t; [@key "locationName"]
  failover_priority : int; [@key "failoverPriority"]
  is_zone_redundant : bool; [@key "isZoneRedundant"]
}
[@@deriving yojson_of]

type capability = { name : string } [@@deriving yojson_of]

type properties = {
  database_account_offer_type : string; [@key "databaseAccountOfferType"]
  consistency_policy : Consistency.policy; [@key "consistencyPolicy"]
  locations : location list;
  capabilities : capability list; [@yojson_drop_if List.is_empty]
  enable_free_tier : bool; [@key "enableFreeTier"]
}
[@@deriving yojson_of]

type id_resource = { id : string } [@@deriving yojson_of]

type database_properties = {
  resource : id_resource;
  options : Throughput.options option; [@yojson.option]
}
[@@deriving yojson_of]

type partition_key = { paths : string list; kind : string; version : int }
[@@deriving yojson_of]

type container_resource = {
  id : string;
  partition_key : partition_key; [@key "partitionKey"]
  default_ttl : int option; [@key "defaultTtl"] [@yojson.option]
}
[@@deriving yojson_of]

type container_properties = {
  resource : container_resource;
  options : Throughput.options option; [@yojson.option]
}
[@@deriving yojson_of]

let child ~type_name ~name ~parent properties : Arm_resource.t =
  {
    type_name;
    api_version;
    name;
    location = None;
    tags = [];
    sku = None;
    kind = None;
    depends_on = [];
    references = [ parent ];
    parameters = [];
    properties;
  }

let container_resource ~database_id ~database_path (container : Container.t) =
  let c = container.config in
  child ~type_name:container_type_name
    ~name:(database_path ^ "/" ^ container.container_name)
    ~parent:database_id
    (yojson_of_container_properties
       {
         resource =
           {
             id = container.container_name;
             partition_key =
               {
                 paths = c.partition_key;
                 kind =
                   (if List.length c.partition_key = 1 then "Hash"
                    else "MultiHash");
                 version = 2;
               };
             default_ttl = c.default_ttl;
           };
         options = Option.map Throughput.options c.throughput;
       })

let database_resources ~account_id ~account_name (db : Database.t) =
  let database_path = account_name ^ "/" ^ db.database_name in
  let database =
    child ~type_name:database_type_name ~name:database_path ~parent:account_id
      (yojson_of_database_properties
         {
           resource = { id = db.database_name };
           options = Option.map Throughput.options db.config.throughput;
         })
  in
  database
  :: List.map
       (container_resource
          ~database_id:(Arm_resource.resource_id database)
          ~database_path)
       db.config.containers

let account_resource { account_name; config = c } ~location : Arm_resource.t =
  let location =
    Option.fold ~none:location ~some:Location.to_expression c.location
  in
  {
    type_name;
    api_version;
    name = account_name;
    location = Some location;
    tags = c.tags;
    sku = None;
    kind = Some "GlobalDocumentDB";
    depends_on = c.depends_on;
    references = Arm_expression.resource_ids location;
    parameters = Arm_expression.parameters location;
    properties =
      yojson_of_properties
        {
          database_account_offer_type = "Standard";
          consistency_policy = Consistency.policy c.consistency;
          locations =
            [
              {
                location_name = location;
                failover_priority = 0;
                is_zone_redundant = false;
              };
            ];
          capabilities =
            (match c.capacity_mode with
            | Serverless -> [ { name = "EnableServerless" } ]
            | Provisioned -> []);
          enable_free_tier = c.free_tier;
        };
  }

let emit state ~location =
  account_resource state ~location
  :: List.concat_map
       (database_resources ~account_id:(state_resource_id state)
          ~account_name:state.account_name)
       state.config.databases

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  let* name =
    Option.to_result ~none:(Error.Cosmos_db Missing_name) config.name
  in
  let* account_name = validate_name name in
  let* () = Consistency.validate config.consistency in
  let* () =
    no_duplicates
      (fun n -> Error.Cosmos_db.Duplicate_database n)
      (List.map (fun (db : Database.t) -> db.database_name) config.databases)
  in
  let* () = check_serverless config in
  let state = { account_name; config } in
  Ok (Resource.make state (emit state))

let to_arm_resources t =
  emit (Resource.state t) ~location:Arm_expression.resource_group_location
