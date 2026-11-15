(* Farmer's first example: a web app, on an App Service plan it creates.
   dune exec examples/first_app.exe   (writes myFirstTemplate.json) *)
open Azf_resources

let ( let* ) = Result.bind

let deployment =
  let* app = Web_app.(build [ name "yourFirstAzfApp" ]) in
  Arm.(build [ location North_europe; add_resource app ])

let () = Arm.quick_write "myFirstTemplate" deployment
