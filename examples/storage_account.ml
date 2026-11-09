(* Prints an ARM template with one storage account:
   dune exec examples/storage_account.exe > template.json *)
open Azf
open Azf_resources

let storage =
  Storage_account.(
    build [ name "azfexamplestorage"; sku Standard_GRS; add_tag "env" "dev" ])

let deployment =
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
  print_endline (Yojson.Safe.pretty_to_string (Deployment.emit deployment))
