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
  name : string;
  sku : sku;
  kind : kind;
  access_tier : access_tier;
  https_only : bool;
  location : Arm_expression.t;
  tags : (string * string) list;
  depends_on : Resource_id.t list;
}

let type_name = "Microsoft.Storage/storageAccounts"
let api_version = "2023-01-01"

let default =
  {
    name = "";
    sku = Standard_LRS;
    kind = Storage_v2;
    access_tier = Hot;
    https_only = true;
    location = Arm_expression.resource_group_location;
    tags = [];
    depends_on = [];
  }

let build transformers = List.fold_left (fun c f -> f c) default transformers
let name name c = { c with name }
let sku sku c = { c with sku }
let kind kind c = { c with kind }
let access_tier access_tier c = { c with access_tier }
let https_only https_only c = { c with https_only }
let location location c = { c with location }
let add_tags tags c = { c with tags = c.tags @ tags }
let add_tag key value = add_tags [ (key, value) ]
let depends_on id c = { c with depends_on = c.depends_on @ [ id ] }
let resource_id c = Resource_id.make ~type_name c.name

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

let access_tier_to_string = function Hot -> "Hot" | Cool -> "Cool"

let to_arm_resource c : Arm_resource.t =
  {
    type_name;
    api_version;
    name = c.name;
    location = Some c.location;
    tags = c.tags;
    sku = Some (`Assoc [ ("name", `String (sku_to_string c.sku)) ]);
    kind = Some (kind_to_string c.kind);
    depends_on = c.depends_on;
    properties =
      `Assoc
        [
          ("accessTier", `String (access_tier_to_string c.access_tier));
          ("supportsHttpsTrafficOnly", `Bool c.https_only);
          ("minimumTlsVersion", `String "TLS1_2");
        ];
  }
