(* Deploys a web app with the Azure CLI (run `az login` first):
   DB_PASSWORD=... dune exec examples/deploy.exe -- my-rg westeurope *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let deployment =
  let* plan = Server_farm.(build [ name "azf-deploy-plan" ]) in
  let* app =
    Web_app.(
      build
        [
          name "azf-deploy-app";
          service_plan plan;
          add_secret_setting "DB_PASSWORD";
        ])
  in
  Arm.(
    build
      [
        add_resource plan;
        add_resource app;
        add_output (Output.string "hostName" (Web_app.default_host_name app));
      ])

let deploy deployment ~group ~location ~password =
  let config =
    Azf_deploy.Az_cli.Config.(
      build ~az:"az" ~resource_group:group ~name:"azf-example"
        [ parameter "DB_PASSWORD" (String password) ])
  in
  let* () = Azf_deploy.Az_cli.create_resource_group config ~location in
  Azf_deploy.Az_cli.create config deployment

let () =
  match (deployment, Sys.argv, Sys.getenv_opt "DB_PASSWORD") with
  | Error e, _, _ ->
      prerr_endline (Error.to_string e);
      exit 1
  | Ok deployment, [| _; group; location |], Some password when password <> ""
    -> (
      match deploy deployment ~group ~location ~password with
      | Ok outputs ->
          List.iter
            (fun (key, value) -> Printf.printf "%s: %s\n" key value)
            outputs
      | Error e ->
          prerr_endline (Azf_deploy.Az_cli.Error.to_string e);
          exit 1)
  | Ok _, _, _ ->
      prerr_endline
        "usage: DB_PASSWORD=... deploy.exe <resource-group> <location>";
      exit 2
