module Storage_account = struct
  type t = Missing_name | Invalid_name of string

  let to_string = function
    | Missing_name -> "Storage account name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid storage account name %S: must be 3-24 characters, lowercase \
           letters and digits only"
          name
end

module Server_farm = struct
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

module Web_app = struct
  type t =
    | Missing_name
    | Invalid_name of string
    | Missing_service_plan
    | Python_requires_linux of string

  let to_string = function
    | Missing_name -> "Web app name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid web app name %S: must be 2-60 characters, letters, digits \
           and hyphens only, not starting or ending with a hyphen"
          name
    | Missing_service_plan -> "Web app service plan is required"
    | Python_requires_linux version ->
        Printf.sprintf "Python %s requires a Linux service plan" version
end

module Cosmos_db = struct
  type t =
    | Missing_name
    | Invalid_name of string
    | Invalid_bounded_staleness of {
        max_staleness_prefix : int;
        max_interval_seconds : int;
      }
    | Duplicate_database of string
    | Throughput_on_serverless of string
    | Missing_database_name
    | Invalid_database_name of string
    | Invalid_provisioned_throughput of int
    | Invalid_autoscale_throughput of int
    | Duplicate_container of string
    | Missing_container_name
    | Invalid_container_name of string
    | Missing_partition_key of string
    | Invalid_partition_key of string list
    | Invalid_default_ttl of int

  let invalid_id kind id =
    Printf.sprintf
      "Invalid Cosmos DB %s name %S: must be 1-255 characters, without / \\ # \
       ? and not ending with a space"
      kind id

  let to_string = function
    | Missing_name -> "Cosmos DB account name is required"
    | Invalid_name name ->
        Printf.sprintf
          "Invalid Cosmos DB account name %S: must be 3-44 characters, \
           lowercase letters, digits and hyphens only, not starting or ending \
           with a hyphen"
          name
    | Invalid_bounded_staleness { max_staleness_prefix; max_interval_seconds }
      ->
        Printf.sprintf
          "Invalid Cosmos DB bounded staleness (prefix %d, interval %ds): the \
           prefix must be at least 10 and the interval 5-86400 seconds"
          max_staleness_prefix max_interval_seconds
    | Duplicate_database name ->
        Printf.sprintf "Duplicate Cosmos DB database %S" name
    | Throughput_on_serverless name ->
        Printf.sprintf
          "Cosmos DB %S sets throughput, but the account is serverless" name
    | Missing_database_name -> "Cosmos DB database name is required"
    | Invalid_database_name name -> invalid_id "database" name
    | Invalid_provisioned_throughput ru ->
        Printf.sprintf
          "Invalid Cosmos DB throughput %d RU/s: must be at least 400 and a \
           multiple of 100"
          ru
    | Invalid_autoscale_throughput ru ->
        Printf.sprintf
          "Invalid Cosmos DB autoscale max throughput %d RU/s: must be at \
           least 1000 and a multiple of 1000"
          ru
    | Duplicate_container name ->
        Printf.sprintf "Duplicate Cosmos DB container %S" name
    | Missing_container_name -> "Cosmos DB container name is required"
    | Invalid_container_name name -> invalid_id "container" name
    | Missing_partition_key name ->
        Printf.sprintf "Cosmos DB container %S needs a partition key" name
    | Invalid_partition_key paths ->
        Printf.sprintf
          "Invalid Cosmos DB partition key [%s]: must be 1-3 paths, each \
           starting with /"
          (String.concat "; " paths)
    | Invalid_default_ttl ttl ->
        Printf.sprintf
          "Invalid Cosmos DB default TTL %d: must be -1 (no default) or at \
           least 1 second"
          ttl
end

type t =
  | Storage_account of Storage_account.t
  | Server_farm of Server_farm.t
  | Web_app of Web_app.t
  | Cosmos_db of Cosmos_db.t

let to_string = function
  | Storage_account e -> Storage_account.to_string e
  | Server_farm e -> Server_farm.to_string e
  | Web_app e -> Web_app.to_string e
  | Cosmos_db e -> Cosmos_db.to_string e
