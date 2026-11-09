open Azf
open Azf_resources

let print_resource config =
  Storage_account.to_arm_resource config
  |> Arm_resource.to_json |> Yojson.Safe.pretty_to_string |> print_endline

let%expect_test "defaults" =
  print_resource Storage_account.(build [ name "mystorage" ]);
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
  print_resource
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
      match
        (Storage_account.(build [ sku s ]) |> Storage_account.to_arm_resource)
          .sku
      with
      | Some (`Assoc [ ("name", `String n) ]) -> print_endline n
      | _ -> print_endline "unexpected");
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
      (Storage_account.(build [ kind k ]) |> Storage_account.to_arm_resource)
        .kind
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
  let id = Storage_account.(resource_id (build [ name "mystorage" ])) in
  print_endline (Arm_expression.to_string (Resource_id id));
  [%expect {| [resourceId('Microsoft.Storage/storageAccounts', 'mystorage')] |}]
