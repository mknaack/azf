open Azf
open Azf_resources

let print_result = function
  | Ok logs ->
      print_endline
        (Arm_resource.to_string (Log_analytics.to_arm_resource logs))
  | Error e -> print_endline (Error.to_string e)

let%expect_test "defaults" =
  print_result Log_analytics.(build [ name "my-logs" ]);
  [%expect
    {|
    {
      "type": "Microsoft.OperationalInsights/workspaces",
      "apiVersion": "2023-09-01",
      "name": "my-logs",
      "location": "[resourceGroup().location]",
      "properties": { "sku": { "name": "PerGB2018" }, "retentionInDays": 30 }
    }
    |}]

let%expect_test "all settings" =
  print_result
    Log_analytics.(
      build
        [
          name "my-logs";
          retention_days 90;
          daily_cap_gb 0.5;
          location (String "westeurope");
          add_tag "team" "core";
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.OperationalInsights/workspaces",
      "apiVersion": "2023-09-01",
      "name": "my-logs",
      "location": "westeurope",
      "tags": { "team": "core" },
      "properties": {
        "sku": { "name": "PerGB2018" },
        "retentionInDays": 90,
        "workspaceCapping": { "dailyQuotaGb": 0.5 }
      }
    }
    |}]

let%expect_test "missing name" =
  print_result (Log_analytics.build []);
  [%expect {| Log Analytics workspace name is required |}]

let%expect_test "name rules" =
  [
    "abc";
    "abcd";
    String.make 63 'a';
    String.make 64 'a';
    "-logs";
    "logs-";
    "my_logs";
    "My-Logs-1";
  ]
  |> List.iter (fun n ->
      match Log_analytics.validate_name n with
      | Ok _ -> Printf.printf "ok %d\n" (String.length n)
      | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Invalid Log Analytics workspace name "abc": must be 4-63 characters, letters, digits and hyphens only, starting and ending with a letter or digit
    ok 4
    ok 63
    Invalid Log Analytics workspace name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": must be 4-63 characters, letters, digits and hyphens only, starting and ending with a letter or digit
    Invalid Log Analytics workspace name "-logs": must be 4-63 characters, letters, digits and hyphens only, starting and ending with a letter or digit
    Invalid Log Analytics workspace name "logs-": must be 4-63 characters, letters, digits and hyphens only, starting and ending with a letter or digit
    Invalid Log Analytics workspace name "my_logs": must be 4-63 characters, letters, digits and hyphens only, starting and ending with a letter or digit
    ok 9
    |}]

let%expect_test "retention limits" =
  [ 29; 30; 730; 731 ]
  |> List.iter (fun days ->
      match Log_analytics.(build [ name "my-logs"; retention_days days ]) with
      | Ok _ -> Printf.printf "ok %d\n" days
      | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Invalid Log Analytics retention 29 days: must be 30-730
    ok 30
    ok 730
    Invalid Log Analytics retention 731 days: must be 30-730
    |}]
