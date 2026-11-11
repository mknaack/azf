open Azf
open Azf_resources

let plan ?(os = Server_farm.Os.Windows) () =
  Server_farm.build [ Server_farm.name "myplan"; Server_farm.os os ]
  |> Result.get_ok

let print_result = function
  | Ok app ->
      print_endline (Arm_resource.to_string (Web_app.to_arm_resource app))
  | Error e -> print_endline (Web_app.Error.to_string e)

let%expect_test "defaults depend on the service plan" =
  print_result Web_app.(build [ name "myapp"; service_plan (plan ()) ]);
  [%expect
    {|
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2022-09-01",
      "name": "myapp",
      "location": "[resourceGroup().location]",
      "kind": "app",
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
        "httpsOnly": true,
        "siteConfig": { "alwaysOn": false, "minTlsVersion": "1.2" }
      }
    }
    |}]

let%expect_test "linux app with settings" =
  let storage = Storage_account.(build [ name "mystorage" ]) |> Result.get_ok in
  print_result
    Web_app.(
      build
        [
          name "myapp";
          service_plan (plan ~os:Linux ());
          always_on true;
          https_only false;
          add_setting "ENV" (String "dev");
          add_setting "STORAGE" (Storage_account.connection_string storage);
          add_setting "ENV" (String "prod");
          add_tag "team" "core";
          depends_on (Storage_account.resource_id storage);
          depends_on (Server_farm.resource_id (plan ()));
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2022-09-01",
      "name": "myapp",
      "location": "[resourceGroup().location]",
      "tags": { "team": "core" },
      "kind": "app,linux",
      "dependsOn": [
        "[resourceId('Microsoft.Storage/storageAccounts', 'mystorage')]",
        "[resourceId('Microsoft.Web/serverfarms', 'myplan')]"
      ],
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
        "httpsOnly": false,
        "siteConfig": {
          "alwaysOn": true,
          "minTlsVersion": "1.2",
          "appSettings": [
            {
              "name": "STORAGE",
              "value": "[concat('DefaultEndpointsProtocol=https;AccountName=', 'mystorage', ';AccountKey=', listKeys(resourceId('Microsoft.Storage/storageAccounts', 'mystorage'), '2023-01-01').keys[0].value, ';EndpointSuffix=', environment().suffixes.storage)]"
            },
            { "name": "ENV", "value": "prod" }
          ]
        }
      }
    }
    |}]

let%expect_test "validation" =
  [
    Web_app.build [ Web_app.service_plan (plan ()) ];
    Web_app.(build [ name "a"; service_plan (plan ()) ]);
    Web_app.(build [ name "-myapp"; service_plan (plan ()) ]);
    Web_app.(build [ name "myapp-"; service_plan (plan ()) ]);
    Web_app.(build [ name "my.app"; service_plan (plan ()) ]);
    Web_app.(build [ name (String.make 61 'a'); service_plan (plan ()) ]);
    Web_app.(build [ name "myapp" ]);
    Web_app.(build [ name "My-App-01"; service_plan (plan ()) ]);
  ]
  |> List.iter (function
    | Ok app ->
        print_endline ("ok " ^ Resource_id.name (Web_app.resource_id app))
    | Error e -> print_endline (Web_app.Error.to_string e));
  [%expect
    {|
    Web app name is required
    Invalid web app name "a": must be 2-60 characters, letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid web app name "-myapp": must be 2-60 characters, letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid web app name "myapp-": must be 2-60 characters, letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid web app name "my.app": must be 2-60 characters, letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid web app name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": must be 2-60 characters, letters, digits and hyphens only, not starting or ending with a hyphen
    Web app service plan is required
    ok My-App-01
    |}]

let%expect_test "default host name" =
  Web_app.(build [ name "myapp"; service_plan (plan ()) ])
  |> Result.get_ok |> Web_app.default_host_name |> Arm_expression.to_string
  |> print_endline;
  [%expect
    {| [reference(resourceId('Microsoft.Web/sites', 'myapp')).defaultHostName] |}]

let%expect_test "deployment infers dependsOn within the deployment" =
  let storage = Storage_account.(build [ name "mystorage" ]) |> Result.get_ok in
  let deployed_plan = plan () in
  let external_plan =
    Server_farm.(build [ name "sharedplan" ]) |> Result.get_ok
  in
  let app plan settings =
    Web_app.build (Web_app.name "myapp" :: Web_app.service_plan plan :: settings)
    |> Result.get_ok |> Web_app.to_arm_resource
  in
  let deps resources =
    Deployment.(build [ add_resources resources ])
    |> Deployment.to_string |> print_endline
  in
  deps
    [
      app deployed_plan
        Web_app.
          [
            add_setting "A" (Storage_account.connection_string storage);
            add_setting "B" (Storage_account.connection_string storage);
            depends_on (Server_farm.resource_id deployed_plan);
          ];
      Server_farm.to_arm_resource deployed_plan;
      Storage_account.to_arm_resource storage;
    ];
  deps [ app external_plan [] ];
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "[resourceGroup().location]",
          "kind": "app",
          "dependsOn": [
            "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
            "[resourceId('Microsoft.Storage/storageAccounts', 'mystorage')]"
          ],
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
            "httpsOnly": true,
            "siteConfig": {
              "alwaysOn": false,
              "minTlsVersion": "1.2",
              "appSettings": [
                {
                  "name": "A",
                  "value": "[concat('DefaultEndpointsProtocol=https;AccountName=', 'mystorage', ';AccountKey=', listKeys(resourceId('Microsoft.Storage/storageAccounts', 'mystorage'), '2023-01-01').keys[0].value, ';EndpointSuffix=', environment().suffixes.storage)]"
                },
                {
                  "name": "B",
                  "value": "[concat('DefaultEndpointsProtocol=https;AccountName=', 'mystorage', ';AccountKey=', listKeys(resourceId('Microsoft.Storage/storageAccounts', 'mystorage'), '2023-01-01').keys[0].value, ';EndpointSuffix=', environment().suffixes.storage)]"
                }
              ]
            }
          }
        },
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "myplan",
          "location": "[resourceGroup().location]",
          "sku": { "name": "F1", "tier": "Free", "capacity": 1 },
          "kind": "app",
          "properties": { "reserved": false }
        },
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
      ],
      "outputs": {}
    }
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "[resourceGroup().location]",
          "kind": "app",
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'sharedplan')]",
            "httpsOnly": true,
            "siteConfig": { "alwaysOn": false, "minTlsVersion": "1.2" }
          }
        }
      ],
      "outputs": {}
    }
    |}]

let%expect_test "runtime" =
  let build os set_runtime =
    print_result
      Web_app.(build [ name "myapp"; service_plan (plan ~os ()); set_runtime ])
  in
  build Linux (Web_app.runtime (Dotnet "8.0"));
  build Windows (Web_app.runtime (Java "17"));
  build Windows (Web_app.runtime (Python "3.12"));
  [%expect
    {|
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2022-09-01",
      "name": "myapp",
      "location": "[resourceGroup().location]",
      "kind": "app,linux",
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
        "httpsOnly": true,
        "siteConfig": {
          "alwaysOn": false,
          "linuxFxVersion": "DOTNETCORE|8.0",
          "minTlsVersion": "1.2"
        }
      }
    }
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2022-09-01",
      "name": "myapp",
      "location": "[resourceGroup().location]",
      "kind": "app",
      "properties": {
        "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
        "httpsOnly": true,
        "siteConfig": {
          "alwaysOn": false,
          "javaVersion": "17",
          "javaContainer": "JAVA",
          "javaContainerVersion": "SE",
          "minTlsVersion": "1.2"
        }
      }
    }
    Runtime PYTHON|3.12 is not supported on Windows plans
    |}]
