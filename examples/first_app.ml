(* Farmer's first example: a web app on an App Service plan.
   dune exec examples/first_app.exe   (writes myFirstTemplate.json) *)
open Azf_resources

let ( let* ) = Result.bind

let deployment =
  let* plan = Server_farm.(build [ name "yourFirstAzfApp-farm" ]) in
  let* app = Web_app.(build [ name "yourFirstAzfApp"; service_plan plan ]) in
  Arm.(build [ location North_europe; add_resource plan; add_resource app ])

let () = Arm.quick_write "myFirstTemplate" deployment
