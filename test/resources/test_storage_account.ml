open Azf
open Azf_resources

let print_result = function
  | Ok account ->
      Storage_account.to_arm_resource account
      |> Arm_resource.yojson_of_t |> Yojson.Safe.pretty_to_string
      |> print_endline
  | Error e -> print_endline (Storage_account.error_to_string e)

let arm_resource transformers =
  Storage_account.build (Storage_account.name "mystorage" :: transformers)
  |> Result.get_ok |> Storage_account.to_arm_resource

let%expect_test "defaults" =
  print_result Storage_account.(build [ name "mystorage" ]);
  [%expect
    {|
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "mystorage",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Standard_LRS" },
      "kind": "StorageV2",
      "properties": {
        "accessTier": "Hot",
        "supportsHttpsTrafficOnly": true,
        "minimumTlsVersion": "TLS1_2"
      }
    }
    |}]

let%expect_test "all settings" =
  let other = Resource_id.make ~type_name:"Microsoft.Web/sites" "myapp" in
  print_result
    Storage_account.(
      build
        [
          name "mystorage";
          sku Premium_ZRS;
          kind Block_blob_storage;
          access_tier Cool;
          https_only false;
          location (String "westeurope");
          add_tag "env" "dev";
          add_tags [ ("team", "core") ];
          depends_on other;
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "mystorage",
      "location": "westeurope",
      "tags": { "env": "dev", "team": "core" },
      "sku": { "name": "Premium_ZRS" },
      "kind": "BlockBlobStorage",
      "dependsOn": [ "[resourceId('Microsoft.Web/sites', 'myapp')]" ],
      "properties": {
        "accessTier": "Cool",
        "supportsHttpsTrafficOnly": false,
        "minimumTlsVersion": "TLS1_2"
      }
    }
    |}]

let%expect_test "name validation" =
  [
    Storage_account.build [];
    Storage_account.(build [ name "" ]);
    Storage_account.(build [ name "ab" ]);
    Storage_account.(build [ name "abc" ]);
    Storage_account.(build [ name (String.make 24 'a') ]);
    Storage_account.(build [ name (String.make 25 'a') ]);
    Storage_account.(build [ name "MyStorage" ]);
    Storage_account.(build [ name "my-storage" ]);
    Storage_account.(build [ name "storage01" ]);
  ]
  |> List.iter (function
    | Ok account ->
        print_endline
          ("ok " ^ Resource_id.name (Storage_account.resource_id account))
    | Error e -> print_endline (Storage_account.error_to_string e));
  [%expect
    {|
    Storage account name is required
    Invalid storage account name "": must be 3-24 characters, lowercase letters and digits only
    Invalid storage account name "ab": must be 3-24 characters, lowercase letters and digits only
    ok abc
    ok aaaaaaaaaaaaaaaaaaaaaaaa
    Invalid storage account name "aaaaaaaaaaaaaaaaaaaaaaaaa": must be 3-24 characters, lowercase letters and digits only
    Invalid storage account name "MyStorage": must be 3-24 characters, lowercase letters and digits only
    Invalid storage account name "my-storage": must be 3-24 characters, lowercase letters and digits only
    ok storage01
    |}]

let%expect_test "last name wins" =
  print_result Storage_account.(build [ name "first"; name "second" ]);
  [%expect
    {|
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "second",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Standard_LRS" },
      "kind": "StorageV2",
      "properties": {
        "accessTier": "Hot",
        "supportsHttpsTrafficOnly": true,
        "minimumTlsVersion": "TLS1_2"
      }
    }
    |}]

let%expect_test "skus" =
  Storage_account.
    [
      Standard_LRS;
      Standard_GRS;
      Standard_RAGRS;
      Standard_ZRS;
      Standard_GZRS;
      Standard_RAGZRS;
      Premium_LRS;
      Premium_ZRS;
    ]
  |> List.iter (fun s ->
      match (arm_resource [ Storage_account.sku s ]).sku with
      | Some sku -> print_endline sku.name
      | None -> print_endline "none");
  [%expect
    {|
    Standard_LRS
    Standard_GRS
    Standard_RAGRS
    Standard_ZRS
    Standard_GZRS
    Standard_RAGZRS
    Premium_LRS
    Premium_ZRS
    |}]

let%expect_test "kinds" =
  Storage_account.
    [ Storage_v2; Storage; Blob_storage; Block_blob_storage; File_storage ]
  |> List.iter (fun k ->
      (arm_resource [ Storage_account.kind k ]).kind
      |> Option.value ~default:"none"
      |> print_endline);
  [%expect
    {|
    StorageV2
    Storage
    BlobStorage
    BlockBlobStorage
    FileStorage
    |}]

let%expect_test "resource id" =
  let id =
    Storage_account.(build [ name "mystorage" ])
    |> Result.get_ok |> Storage_account.resource_id
  in
  print_endline (Arm_expression.to_string (Resource_id id));
  [%expect {| [resourceId('Microsoft.Storage/storageAccounts', 'mystorage')] |}]
