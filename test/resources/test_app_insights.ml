open Azf
open Azf_resources

let logs = Log_analytics.(build [ name "my-logs" ]) |> Result.get_ok

let print_result = function
  | Ok ai ->
      print_endline (Arm_resource.to_string (App_insights.to_arm_resource ai))
  | Error e -> print_endline (Error.to_string e)

let%expect_test "defaults use the workspace" =
  print_result App_insights.(build [ name "my-ai"; workspace logs ]);
  [%expect
    {|
    {
      "type": "Microsoft.Insights/components",
      "apiVersion": "2020-02-02",
      "name": "my-ai",
      "location": "[resourceGroup().location]",
      "kind": "web",
      "properties": {
        "Application_Type": "web",
        "WorkspaceResourceId": "[resourceId('Microsoft.OperationalInsights/workspaces', 'my-logs')]",
        "IngestionMode": "LogAnalytics",
        "DisableIpMasking": false
      }
    }
    |}]

let%expect_test "all settings" =
  print_result
    App_insights.(
      build
        [
          name "my-ai";
          workspace logs;
          sampling_percentage 25.;
          disable_ip_masking true;
          add_tag "team" "core";
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.Insights/components",
      "apiVersion": "2020-02-02",
      "name": "my-ai",
      "location": "[resourceGroup().location]",
      "tags": { "team": "core" },
      "kind": "web",
      "properties": {
        "Application_Type": "web",
        "WorkspaceResourceId": "[resourceId('Microsoft.OperationalInsights/workspaces', 'my-logs')]",
        "IngestionMode": "LogAnalytics",
        "DisableIpMasking": true,
        "SamplingPercentage": 25.0
      }
    }
    |}]

let%expect_test "missing name and workspace" =
  print_result (App_insights.build [ App_insights.workspace logs ]);
  print_result App_insights.(build [ name "my-ai" ]);
  [%expect
    {|
    App Insights name is required
    App Insights requires a Log Analytics workspace
    |}]

let%expect_test "sampling percentage limits" =
  [ 0.; 0.1; 100.; 100.5 ]
  |> List.iter (fun p ->
      match
        App_insights.(
          build [ name "my-ai"; workspace logs; sampling_percentage p ])
      with
      | Ok _ -> Printf.printf "ok %g\n" p
      | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Invalid App Insights sampling percentage 0: must be above 0 and at most 100
    ok 0.1
    ok 100
    Invalid App Insights sampling percentage 100.5: must be above 0 and at most 100
    |}]

let%expect_test "name rules" =
  [
    "";
    "my-ai";
    "My AI (prod)";
    String.make 260 'a';
    String.make 261 'a';
    "ai.";
    "ai ";
    "a/b";
    "50%";
  ]
  |> List.iter (fun n ->
      match App_insights.validate_name n with
      | Ok _ -> Printf.printf "ok %d\n" (String.length n)
      | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Invalid App Insights name "": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    ok 5
    ok 12
    ok 260
    Invalid App Insights name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    Invalid App Insights name "ai.": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    Invalid App Insights name "ai ": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    Invalid App Insights name "a/b": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    Invalid App Insights name "50%": must be 1-260 characters, without %&\?/ or control characters, not ending with a space or period
    |}]

let%expect_test "web app connected to app insights" =
  let ai =
    App_insights.(build [ name "my-ai"; workspace logs ]) |> Result.get_ok
  in
  let plan = Server_farm.(build [ name "myplan" ]) |> Result.get_ok in
  let app =
    Web_app.(build [ name "myapp"; service_plan plan; app_insights ai ])
    |> Result.get_ok
  in
  Deployment.build
    [
      Deployment.add_resources
        [
          Log_analytics.to_arm_resource logs;
          App_insights.to_arm_resource ai;
          Server_farm.to_arm_resource plan;
          Web_app.to_arm_resource app;
        ];
      Deployment.add_output
        (Output.string "instrumentationKey"
           (App_insights.instrumentation_key ai));
    ]
  |> Deployment.to_string |> print_endline;
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.OperationalInsights/workspaces",
          "apiVersion": "2023-09-01",
          "name": "my-logs",
          "location": "[resourceGroup().location]",
          "properties": { "sku": { "name": "PerGB2018" }, "retentionInDays": 30 }
        },
        {
          "type": "Microsoft.Insights/components",
          "apiVersion": "2020-02-02",
          "name": "my-ai",
          "location": "[resourceGroup().location]",
          "kind": "web",
          "dependsOn": [
            "[resourceId('Microsoft.OperationalInsights/workspaces', 'my-logs')]"
          ],
          "properties": {
            "Application_Type": "web",
            "WorkspaceResourceId": "[resourceId('Microsoft.OperationalInsights/workspaces', 'my-logs')]",
            "IngestionMode": "LogAnalytics",
            "DisableIpMasking": false
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
          "type": "Microsoft.Web/sites",
          "apiVersion": "2022-09-01",
          "name": "myapp",
          "location": "[resourceGroup().location]",
          "kind": "app",
          "dependsOn": [
            "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
            "[resourceId('Microsoft.Insights/components', 'my-ai')]"
          ],
          "properties": {
            "serverFarmId": "[resourceId('Microsoft.Web/serverfarms', 'myplan')]",
            "httpsOnly": true,
            "siteConfig": {
              "alwaysOn": false,
              "minTlsVersion": "1.2",
              "appSettings": [
                {
                  "name": "APPLICATIONINSIGHTS_CONNECTION_STRING",
                  "value": "[reference(resourceId('Microsoft.Insights/components', 'my-ai')).ConnectionString]"
                }
              ]
            }
          }
        }
      ],
      "outputs": {
        "instrumentationKey": {
          "type": "string",
          "value": "[reference(resourceId('Microsoft.Insights/components', 'my-ai')).InstrumentationKey]"
        }
      }
    }
    |}]
