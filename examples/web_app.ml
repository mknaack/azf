(* Farmer's canonical example: a web app on an App Service plan, with a
   storage account connection string in its settings.
   dune exec examples/web_app.exe > template.json *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let template =
  let* storage =
    Storage_account.(build [ name "azfexamplestorage" ])
    |> Result.map_error Storage_account.Error.to_string
  in
  let* plan =
    Server_farm.(build [ name "azf-example-plan"; sku B1; os Linux ])
    |> Result.map_error Server_farm.Error.to_string
  in
  let* app =
    Web_app.(
      build
        [
          name "azf-example-app";
          service_plan plan;
          always_on true;
          add_setting "STORAGE_CONNECTION"
            (Storage_account.connection_string storage);
          depends_on (Storage_account.resource_id storage);
        ])
    |> Result.map_error Web_app.Error.to_string
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
      prerr_endline e;
      exit 1
