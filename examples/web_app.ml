(* Farmer's canonical example: a web app on an App Service plan, with a
   storage account connection string in its settings.
   dune exec examples/web_app.exe > template.json *)
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
       ])

let () =
  match template with
  | Ok deployment -> print_endline (Deployment.to_string deployment)
  | Error e ->
      prerr_endline (Error.to_string e);
      exit 1
