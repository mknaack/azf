(* A storage account and its blob endpoint.
   dune exec examples/storage_account.exe   (writes storage_account.json) *)
open Azf
open Azf_resources

let ( let* ) = Result.bind

let deployment =
  let* storage =
    Storage_account.(
      build [ name "azfexamplestorage"; sku Standard_GRS; add_tag "env" "dev" ])
  in
  Arm.(
    build
      [
        add_resource storage;
        add_output
          (Output.string "blobEndpoint" (Storage_account.blob_endpoint storage));
      ])

let () = Arm.quick_write "storage_account" deployment
