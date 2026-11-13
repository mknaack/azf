open Azf

(* A fake az that logs its arguments (and the parameters file it is given) and
   prints [stdout]. *)
let fake_az ?(stdout = "") ?(exit_code = 0) () =
  let script = Filename.temp_file "fake_az" ".sh" in
  let log = Filename.temp_file "fake_az" ".log" in
  let stdout_file = Filename.temp_file "fake_az" ".stdout" in
  Out_channel.with_open_text stdout_file (fun oc ->
      Out_channel.output_string oc stdout);
  Out_channel.with_open_text script (fun oc ->
      Printf.fprintf oc
        {|#!/bin/sh
for arg in "$@"; do
  case "$arg" in
    @*) echo "@<parameters file>"; cat "${arg#@}"; echo ;;
    *.json) if [ -f "$arg" ]; then echo "<template file>"; else echo "missing $arg"; fi ;;
    *) echo "$arg" ;;
  esac
done > %s
cat %s
echo "ERROR: something went wrong" >&2
exit %d
|}
        log stdout_file exit_code);
  Unix.chmod script 0o700;
  ( script,
    fun () -> print_string (In_channel.with_open_text log In_channel.input_all)
  )

let deployment =
  Deployment.build
    [
      Deployment.add_output
        (Output.string "secret"
           (Parameter (Parameter.secure_string "DB_PASSWORD")));
    ]

let print_result to_string = function
  | Ok v -> print_endline ("Ok " ^ to_string v)
  | Error e -> print_endline ("Error: " ^ Azf_deploy.Az_cli.Error.to_string e)

let%expect_test "validate" =
  let script, print_log = fake_az () in
  Azf_deploy.Az_cli.(
    validate
      [
        az script;
        resource_group "my-rg";
        parameter "DB_PASSWORD" (String "s3cret");
        parameter "tags" (Object [ ("env", String "dev") ]);
      ]
      deployment)
  |> print_result (fun () -> "()");
  print_log ();
  [%expect
    {|
    Ok ()
    deployment
    group
    validate
    --resource-group
    my-rg
    --name
    azf
    --template-file
    <template file>
    --mode
    Incremental
    --parameters
    @<parameters file>
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "DB_PASSWORD": { "value": "s3cret" },
        "tags": { "value": { "env": "dev" } }
      }
    }
    --output
    none
    |}]

let%expect_test "create returns outputs" =
  let stdout =
    {|{ "name": "web", "properties": { "outputs": {
        "hostName": { "type": "String", "value": "app.azurewebsites.net" },
        "count": { "type": "Int", "value": 3 } } } }|}
  in
  let script, print_log = fake_az ~stdout () in
  Azf_deploy.Az_cli.(
    create
      [ az script; resource_group "my-rg"; name "web"; mode Complete ]
      deployment)
  |> print_result (fun outputs ->
      String.concat ", " (List.map (fun (k, v) -> k ^ " = " ^ v) outputs));
  print_log ();
  [%expect
    {|
    Ok hostName = app.azurewebsites.net, count = 3
    deployment
    group
    create
    --resource-group
    my-rg
    --name
    web
    --template-file
    <template file>
    --mode
    Complete
    --output
    json
    |}]

let%expect_test "what-if returns the report" =
  let script, _ = fake_az ~stdout:"Resource changes: 1 to create.\n" () in
  Azf_deploy.Az_cli.(what_if [ az script; resource_group "my-rg" ] deployment)
  |> print_result Fun.id;
  [%expect {| Ok Resource changes: 1 to create. |}]

let%expect_test "create resource group" =
  let script, print_log = fake_az () in
  Azf_deploy.Az_cli.(
    create_resource_group
      [ az script; resource_group "my-rg" ]
      ~location:"westeurope")
  |> print_result (fun () -> "()");
  print_log ();
  [%expect
    {|
    Ok ()
    group
    create
    --name
    my-rg
    --location
    westeurope
    --output
    none
    |}]

let%expect_test "errors" =
  let run transformers =
    Azf_deploy.Az_cli.validate transformers deployment
    |> print_result (fun () -> "()")
  in
  run [];
  let script, _ = fake_az ~exit_code:1 () in
  run Azf_deploy.Az_cli.[ az script; resource_group "my-rg" ];
  run Azf_deploy.Az_cli.[ az "/nonexistent/az"; resource_group "my-rg" ];
  let script, _ = fake_az ~stdout:"not json" () in
  Azf_deploy.Az_cli.(create [ az script; resource_group "my-rg" ] deployment)
  |> print_result (fun _ -> "outputs");
  [%expect
    {|
    Error: no resource group set
    Error: az exited with code 1: ERROR: something went wrong
    Error: could not run /nonexistent/az; is the Azure CLI installed?
    Error: unexpected output from az: not json
    |}]
