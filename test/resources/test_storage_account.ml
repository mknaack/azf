open Azf
open Azf_resources

let print_result = function
  | Ok account ->
      print_endline
        (Arm_resource.to_string (Storage_account.to_arm_resource account))
  | Error e -> print_endline (Storage_account.Error.to_string e)

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
    | Error e -> print_endline (Storage_account.Error.to_string e));
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

let%expect_test "resource id" =
  let id =
    Storage_account.(build [ name "mystorage" ])
    |> Result.get_ok |> Storage_account.resource_id
  in
  print_endline (Arm_expression.to_string (Resource_id id));
  [%expect {| [resourceId('Microsoft.Storage/storageAccounts', 'mystorage')] |}]

let%expect_test "connection string" =
  Storage_account.(build [ name "mystorage" ])
  |> Result.get_ok |> Storage_account.connection_string
  |> Arm_expression.to_string |> print_endline;
  [%expect
    {| [concat('DefaultEndpointsProtocol=https;AccountName=', 'mystorage', ';AccountKey=', listKeys(resourceId('Microsoft.Storage/storageAccounts', 'mystorage'), '2023-01-01').keys[0].value, ';EndpointSuffix=', environment().suffixes.storage)] |}]
