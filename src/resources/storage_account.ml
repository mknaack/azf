open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

type sku =
  | Standard_LRS
  | Standard_GRS
  | Standard_RAGRS
  | Standard_ZRS
  | Standard_GZRS
  | Standard_RAGZRS
  | Premium_LRS
  | Premium_ZRS

type kind =
  | Storage_v2
  | Storage
  | Blob_storage
  | Block_blob_storage
  | File_storage

type access_tier = Hot | Cool

type config = {
  name : string option;
  sku : sku;
  kind : kind;
  access_tier : access_tier;
  https_only : bool;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

type t = { account_name : string; config : config }
type error = Missing_name | Invalid_name of string

let error_to_string = function
  | Missing_name -> "Storage account name is required"
  | Invalid_name name ->
      Printf.sprintf
        "Invalid storage account name %S: must be 3-24 characters, lowercase \
         letters and digits only"
        name

let type_name = "Microsoft.Storage/storageAccounts"
let api_version = "2023-01-01"

let default =
  {
    name = None;
    sku = Standard_LRS;
    kind = Storage_v2;
    access_tier = Hot;
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
  else Error (Invalid_name name)

let build transformers =
  let config = List.fold_left (fun c f -> f c) default transformers in
  match config.name with
  | None -> Error Missing_name
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

let sku_to_string = function
  | Standard_LRS -> "Standard_LRS"
  | Standard_GRS -> "Standard_GRS"
  | Standard_RAGRS -> "Standard_RAGRS"
  | Standard_ZRS -> "Standard_ZRS"
  | Standard_GZRS -> "Standard_GZRS"
  | Standard_RAGZRS -> "Standard_RAGZRS"
  | Premium_LRS -> "Premium_LRS"
  | Premium_ZRS -> "Premium_ZRS"

let kind_to_string = function
  | Storage_v2 -> "StorageV2"
  | Storage -> "Storage"
  | Blob_storage -> "BlobStorage"
  | Block_blob_storage -> "BlockBlobStorage"
  | File_storage -> "FileStorage"

let yojson_of_access_tier = function
  | Hot -> `String "Hot"
  | Cool -> `String "Cool"

type properties = {
  access_tier : access_tier; [@key "accessTier"]
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
    sku = Some (Sku.make (sku_to_string c.sku));
    kind = Some (kind_to_string c.kind);
    depends_on = c.depends_on;
    properties =
      yojson_of_properties
        {
          access_tier = c.access_tier;
          supports_https_traffic_only = c.https_only;
          minimum_tls_version = "TLS1_2";
        };
  }
