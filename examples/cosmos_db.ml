(* A serverless Cosmos DB account with a database and two containers, and its
   endpoint as an output.
   dune exec examples/cosmos_db.exe   (writes cosmos_db.json) *)
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
  Arm.(
    build
      [
        add_resource cosmos;
        add_output (Output.string "endpoint" (Cosmos_db.endpoint cosmos));
      ])

let () = Arm.quick_write "cosmos_db" template
