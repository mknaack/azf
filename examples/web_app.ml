(* Farmer's canonical example: a web app on an App Service plan, with a
   storage account connection string in its settings.
   dune exec examples/web_app.exe > template.json
   DB_PASSWORD=... dune exec examples/web_app.exe -- deploy my-rg westeurope *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let template =
  let* storage = Storage_account.(build [ name "azfexamplestorage" ]) in
  let* plan =
    Server_farm.(build [ name "azf-example-plan"; sku B1; os Linux ])
  in
  let* app =
    Web_app.(
      build
        [
          name "azf-example-app";
          service_plan plan;
          always_on true;
          runtime (Dotnet "8.0");
          add_setting "STORAGE_CONNECTION"
            (Storage_account.connection_string storage);
          add_secret_setting "DB_PASSWORD";
        ])
  in
  Ok
    (Deployment.build
       [
         Deployment.add_resources
           [
             Storage_account.to_arm_resource storage;
             Server_farm.to_arm_resource plan;
             Web_app.to_arm_resource app;
           ];
         Deployment.add_output
           (Output.string "hostName" (Web_app.default_host_name app));
         Deployment.add_output
           (Output.string "blobEndpoint"
              (Storage_account.blob_endpoint storage));
       ])

let deploy deployment ~group ~location ~password =
  let config =
    Azf_deploy.Az_cli.Config.(
      build ~az:"az" ~resource_group:group ~name:"azf-example"
        [ parameter "DB_PASSWORD" (String password) ])
  in
  let* () = Azf_deploy.Az_cli.create_resource_group config ~location in
  let* outputs = Azf_deploy.Az_cli.create config deployment in
  List.iter (fun (key, value) -> Printf.printf "%s: %s\n" key value) outputs;
  Ok ()

let () =
  match (template, Array.to_list Sys.argv) with
  | Error e, _ ->
      prerr_endline (Error.to_string e);
      exit 1
  | Ok deployment, [ _ ] -> print_endline (Deployment.to_string deployment)
  | Ok deployment, [ _; "deploy"; group; location ] -> (
      let password =
        match Sys.getenv_opt "DB_PASSWORD" with
        | Some p when p <> "" -> p
        | _ ->
            prerr_endline "set DB_PASSWORD to deploy";
            exit 2
      in
      match deploy deployment ~group ~location ~password with
      | Ok () -> ()
      | Error e ->
          prerr_endline (Azf_deploy.Az_cli.Error.to_string e);
          exit 1)
  | Ok _, _ ->
      prerr_endline "usage: web_app.exe [deploy <resource-group> <location>]";
      exit 2
