(* Farmer's canonical example: a web app on an App Service plan, with a
   storage account connection string and a secret in its settings.
   dune exec examples/web_app.exe   (writes web_app.json) *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let deployment =
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
  Arm.(
    build
      [
        location West_europe;
        add_resource storage;
        add_resource plan;
        add_resource app;
        add_output (Output.string "hostName" (Web_app.default_host_name app));
      ])

let () = Arm.quick_write "web_app" deployment
