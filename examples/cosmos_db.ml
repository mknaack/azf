(* A serverless Cosmos DB account with a database and two containers, and its
   endpoint as an output.
   dune exec examples/cosmos_db.exe > template.json *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let template =
  let* orders =
    Cosmos_db.Container.(
      build [ name "orders"; partition_key [ "/customerId" ] ])
  in
  let* sessions =
    Cosmos_db.Container.(
      build
        [
          name "sessions";
          partition_key [ "/tenantId"; "/userId" ];
          default_ttl 3600;
        ])
  in
  let* shop =
    Cosmos_db.Database.(
      build [ name "shop"; add_container orders; add_container sessions ])
  in
  let* cosmos =
    Cosmos_db.(
      build
        [
          name "azf-example-cosmos"; capacity_mode Serverless; add_database shop;
        ])
  in
  Ok
    (Deployment.build
       [
         Deployment.add_resources (Cosmos_db.to_arm_resources cosmos);
         Deployment.add_output
           (Output.string "endpoint" (Cosmos_db.endpoint cosmos));
       ])

let () =
  match template with
  | Ok deployment -> print_endline (Deployment.to_string deployment)
  | Error e ->
      prerr_endline (Error.to_string e);
      exit 1
