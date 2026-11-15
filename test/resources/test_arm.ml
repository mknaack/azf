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

let%expect_test "a web app without a plan brings its own" =
  print_result
    (let* app =
       Web_app.(
         build [ name "myapp"; sku B1; os Linux; runtime (Python "3.12") ])
     in
     Arm.(build [ location North_europe; add_resource app ]));
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
          "name": "myapp-farm",
          "location": "northeurope",
          "sku": { "name": "B1", "tier": "Basic", "capacity": 1 },
          "kind": "linux",
          "properties": { "reserved": true }
        },
        {
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "northeurope",
          "kind": "app,linux",
          "dependsOn": [
            "[resourceId('Microsoft.Web/serverfarms', 'myapp-farm')]"
          ],
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myapp-farm')]",
            "httpsOnly": true,
            "siteConfig": {
              "alwaysOn": false,
              "linuxFxVersion": "PYTHON|3.12",
              "minTlsVersion": "1.2"
            }
          }
        }
      ],
      "outputs": {}
    }
    |}]

let%expect_test "the created plan follows the app's location" =
  print_result
    (let* app = Web_app.(build [ name "myapp"; location West_europe ]) in
     Arm.(build [ location North_europe; add_resource app ]));
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
          "name": "myapp-farm",
          "location": "westeurope",
          "sku": { "name": "F1", "tier": "Free", "capacity": 1 },
          "kind": "app",
          "properties": { "reserved": false }
        },
        {
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "westeurope",
          "kind": "app",
          "dependsOn": [
            "[resourceId('Microsoft.Web/serverfarms', 'myapp-farm')]"
          ],
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myapp-farm')]",
            "httpsOnly": true,
            "siteConfig": { "alwaysOn": false, "minTlsVersion": "1.2" }
          }
        }
      ],
      "outputs": {}
    }
    |}]

let%expect_test "created plan validation" =
  [
    Web_app.(build [ name "myapp"; runtime (Python "3.12") ]);
    Web_app.(build [ name (String.make 60 'a') ]);
  ]
  |> List.iter (function
    | Ok _ -> print_endline "ok"
    | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Python 3.12 requires a Linux service plan
    Invalid server farm name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-farm": must be 1-60 characters, letters, digits and hyphens only
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

let%expect_test "name expressions only match the same expression" =
  let check names =
    let result =
      let* storage = Storage_account.(build [ name "mystorage" ]) in
      let raw name : Arm_resource.t =
        { (Storage_account.to_arm_resource storage) with name }
      in
      Arm.(build (List.map (fun n -> add_arm_resource (raw n)) names))
    in
    match result with
    | Ok _ -> print_endline "ok"
    | Error e -> print_endline (Error.to_string e)
  in
  check [ "[base64('a')]"; "[base64('A')]" ];
  check [ "[base64('a')]"; "[base64('a')]" ];
  [%expect
    {|
    ok
    Resource Microsoft.Storage/storageAccounts "[base64('a')]" is added more than once
    |}]

let%expect_test "a created plan clashing with an added one" =
  print_result
    (let* plan = Server_farm.(build [ name "myapp-farm" ]) in
     let* app = Web_app.(build [ name "myapp" ]) in
     Arm.(build [ add_resource plan; add_resource app ]));
  [%expect
    {| Resource Microsoft.Web/serverfarms "myapp-farm" is added more than once |}]
