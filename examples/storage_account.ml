(* Prints an ARM template with one storage account:
   dune exec examples/storage_account.exe > template.json *)
open Azf
open Azf_resources

let deployment storage =
  Deployment.build
    [
      Deployment.add_resource (Storage_account.to_arm_resource storage);
      Deployment.add_output
        (Output.string "blobEndpoint"
           (Property
              ( Reference (Storage_account.resource_id storage),
                "primaryEndpoints.blob" )));
    ]

let () =
  match
    Storage_account.(
      build [ name "azfexamplestorage"; sku Standard_GRS; add_tag "env" "dev" ])
  with
  | Ok storage -> print_endline (Deployment.to_string (deployment storage))
  | Error e ->
      prerr_endline (Storage_account.Error.to_string e);
      exit 1
