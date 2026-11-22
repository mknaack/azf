open Azf
open Azf_resources

let ( let* ) = Result.bind

let print_result = function
  | Ok deployment -> print_endline (Deployment.to_string deployment)
  | Error e -> print_endline (Error.to_string e)

let%expect_test "location applies to resources without their own" =
  print_result
    (let* storage =
       Storage_account.(build [ name "mystorage"; location West_europe ])
     in
     let* plan = Server_farm.(build [ name "myplan" ]) in
     let* app = Web_app.(build [ name "myapp"; service_plan plan ]) in
     Arm.(
       build
         [
           location North_europe;
           add_resource storage;
           add_resource plan;
           add_resource app;
         ]));
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.Storage/storageAccounts",
          "apiVersion": "2023-01-01",
          "name": "mystorage",
          "location": "westeurope",
          "sku": { "name": "Standard_LRS" },
          "kind": "StorageV2",
          "properties": {
            "accessTier": "Hot",
            "supportsHttpsTrafficOnly": true,
            "minimumTlsVersion": "TLS1_2"
          }
        },
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "myplan",
          "location": "northeurope",
          "sku": { "name": "F1", "tier": "Free", "capacity": 1 },
          "kind": "app",
          "properties": { "reserved": false }
        },
        {
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "northeurope",
          "kind": "app",
          "dependsOn": [ "[resourceId('Microsoft.Web/serverfarms', 'myplan')]" ],
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
            "httpsOnly": true,
            "siteConfig": { "alwaysOn": false, "minTlsVersion": "1.2" }
          }
        }
      ],
      "outputs": {}
    }
    |}]

let%expect_test "without a location, resources use the resource group's" =
  print_result
    (let* storage = Storage_account.(build [ name "mystorage" ]) in
     let custom : Arm_resource.t =
       {
         (Storage_account.to_arm_resource storage) with
         name = "custom";
         location = None;
       }
     in
     Arm.(
       build
         [
           add_resource storage;
           add_arm_resource custom;
           add_parameter (Parameter.string "unused");
           add_output
             (Output.string "blob" (Storage_account.blob_endpoint storage));
         ]));
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": { "unused": { "type": "string" } },
      "resources": [
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
        },
        {
          "type": "Microsoft.Storage/storageAccounts",
          "apiVersion": "2023-01-01",
          "name": "custom",
          "sku": { "name": "Standard_LRS" },
          "kind": "StorageV2",
          "properties": {
            "accessTier": "Hot",
            "supportsHttpsTrafficOnly": true,
            "minimumTlsVersion": "TLS1_2"
          }
        }
      ],
      "outputs": {
        "blob": {
          "type": "string",
          "value": "[reference(resourceId('Microsoft.Storage/storageAccounts', 'mystorage')).primaryEndpoints.blob]"
        }
      }
    }
    |}]

let%expect_test "duplicate resources" =
  print_result
    (let* plan = Server_farm.(build [ name "myplan" ]) in
     let* other = Server_farm.(build [ name "MyPlan"; sku B1 ]) in
     Arm.(build [ add_resource plan; add_resource other ]));
  [%expect
    {| Resource Microsoft.Web/serverfarms "myplan" is added more than once |}]

let%expect_test "quick_write writes name.json" =
  Arm.quick_write "quick_write_test"
    Arm.(
      build [ add_resource (Result.get_ok Server_farm.(build [ name "p" ])) ]);
  let ic = open_in "quick_write_test.json" in
  let contents = really_input_string ic (in_channel_length ic) in
  close_in ic;
  Sys.remove "quick_write_test.json";
  print_string contents;
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "p",
          "location": "[resourceGroup().location]",
          "sku": { "name": "F1", "tier": "Free", "capacity": 1 },
          "kind": "app",
          "properties": { "reserved": false }
        }
      ],
      "outputs": {}
    }
    |}]

let%expect_test "bracketed names are literal and compared case-insensitively" =
  let result =
    let* logs = Log_analytics.(build [ name "logs" ]) in
    let* prod = App_insights.(build [ name "[prod]"; workspace logs ]) in
    let* prod' = App_insights.(build [ name "[PROD]"; workspace logs ]) in
    Arm.(build [ add_resource logs; add_resource prod; add_resource prod' ])
  in
  (match result with
  | Ok _ -> print_endline "ok"
  | Error e -> print_endline (Error.to_string e));
  [%expect
    {| Resource Microsoft.Insights/components "[prod]" is added more than once |}]

let%expect_test "a raw resource name starting with [ is emitted as a literal" =
  let result =
    let* storage = Storage_account.(build [ name "mystorage" ]) in
    let raw : Arm_resource.t =
      { (Storage_account.to_arm_resource storage) with name = "[base64('a')]" }
    in
    Arm.(build [ add_arm_resource raw ])
  in
  let template = Deployment.to_string (Result.get_ok result) in
  print_endline
    (List.find
       (fun l -> String.starts_with ~prefix:"\"name\"" (String.trim l))
       (String.split_on_char '\n' template));
  [%expect {| "name": "[[base64('a')]", |}]
