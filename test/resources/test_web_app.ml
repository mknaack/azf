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
      "dependsOn": [ "[resourceId('Microsoft.Web/serverfarms', 'myplan')]" ],
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
        "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
        "[resourceId('Microsoft.Storage/storageAccounts', 'mystorage')]"
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
