open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

module Sku = struct
  type t =
    | Standard_LRS
    | Standard_GRS
    | Standard_RAGRS
    | Standard_ZRS
    | Standard_GZRS
    | Standard_RAGZRS
    | Premium_LRS
    | Premium_ZRS

  let to_string = function
    | Standard_LRS -> "Standard_LRS"
    | Standard_GRS -> "Standard_GRS"
    | Standard_RAGRS -> "Standard_RAGRS"
    | Standard_ZRS -> "Standard_ZRS"
    | Standard_GZRS -> "Standard_GZRS"
    | Standard_RAGZRS -> "Standard_RAGZRS"
    | Premium_LRS -> "Premium_LRS"
    | Premium_ZRS -> "Premium_ZRS"
end

module Kind = struct
  type t =
    | Storage_v2
    | Storage
    | Blob_storage
    | Block_blob_storage
    | File_storage

  let to_string = function
    | Storage_v2 -> "StorageV2"
    | Storage -> "Storage"
    | Blob_storage -> "BlobStorage"
    | Block_blob_storage -> "BlockBlobStorage"
    | File_storage -> "FileStorage"
end

module Access_tier = struct
  type t = Hot | Cool

  let to_string = function Hot -> "Hot" | Cool -> "Cool"
  let yojson_of_t t = `String (to_string t)
end

type config = {
  name : string option;
  sku : Sku.t;
  kind : Kind.t;
  access_tier : Access_tier.t;
  https_only : bool;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = { account_name : string; config : config }

let type_name = "Microsoft.Storage/storageAccounts"
let api_version = "2023-01-01"

let default =
  {
    name = None;
    sku = Sku.Standard_LRS;
    kind = Kind.Storage_v2;
    access_tier = Access_tier.Hot;
    https_only = true;
    location = Arm_expression.resource_group_location;
    tags = [];
    depends_on = [];
  }

let is_lowercase_or_digit = function
  | 'a' .. 'z' | '0' .. '9' -> true
  | _ -> false

let validate_name name =
  let length = String.length name in
  if length >= 3 && length <= 24 && String.for_all is_lowercase_or_digit name
  then Ok name
  else Error (Error.Storage_account (Invalid_name name))

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  match config.name with
  | None -> Error (Error.Storage_account Missing_name)
  | Some name ->
      Result.map
        (fun account_name -> { account_name; config })
        (validate_name name)

let name name c = { c with name = Some name }
let sku sku c = { c with sku }
let kind kind c = { c with kind }
let access_tier access_tier c = { c with access_tier }
let https_only https_only c = { c with https_only }
let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id t = Resource_id.make ~type_name t.account_name

let connection_string t =
  let keys =
    Arm_expression.Call
      ("listKeys", [ Resource_id (resource_id t); String api_version ])
  in
  Arm_expression.Concat
    [
      String "DefaultEndpointsProtocol=https;AccountName=";
      String t.account_name;
      String ";AccountKey=";
      Property (keys, "keys[0].value");
      String ";EndpointSuffix=";
      Property (Call ("environment", []), "suffixes.storage");
    ]

type properties = {
  access_tier : Access_tier.t; [@key "accessTier"]
  supports_https_traffic_only : bool; [@key "supportsHttpsTrafficOnly"]
  minimum_tls_version : string; [@key "minimumTlsVersion"]
}
[@@deriving yojson_of]

let to_arm_resource { account_name; config = c } : Arm_resource.t =
  {
    type_name;
    api_version;
    name = account_name;
    location = Some c.location;
    tags = c.tags;
    sku = Some (Azf.Sku.make (Sku.to_string c.sku));
    kind = Some (Kind.to_string c.kind);
    depends_on = c.depends_on;
    references = Arm_expression.resource_ids c.location;
    properties =
      yojson_of_properties
        {
          access_tier = c.access_tier;
          supports_https_traffic_only = c.https_only;
          minimum_tls_version = "TLS1_2";
        };
  }
