# azf

An OCaml port of [Farmer](https://compositionalit.github.io/farmer/): describe Azure resources with composable builders and emit ARM template JSON.

```ocaml
open Azf_resources

let ( let* ) = Result.bind

let deployment =
  let* app = Web_app.(build [ name "yourFirstAzfApp" ]) in
  Arm.(build [ location North_europe; add_resource app ])

let () = Arm.quick_write "myFirstTemplate" deployment
```

Builders validate their input, so `build` returns a `result` (e.g. storage account names must be 3–24 lowercase letters and digits). All builders share `Azf_resources.Error.t`, so they combine with `let*`. `Arm.build` collects the built resources into a `Deployment.t` (rejecting duplicates), and its `location` applies to every resource built without its own. `Arm.quick_write` writes `myFirstTemplate.json`, printing the error and exiting on failure; use `Deployment.to_string` or `Deployment.write_file` to handle errors yourself.

Dependencies and parameters are worked out from the expressions resources use: a web app whose settings use a storage account's connection string gets that account in its `dependsOn`, and `Web_app.add_secret_setting "DB_PASSWORD"` adds a `securestring` parameter to the template.

## Deploying

`azf.deploy` deploys a template with the [Azure CLI](https://learn.microsoft.com/cli/azure/) (`az login` first). Parameter values are passed in a temporary parameters file, so secrets stay off the command line:

```ocaml
let config =
  Azf_deploy.Az_cli.Config.(
    build ~az:"az" ~resource_group:"my-rg" ~name:"my-deployment"
      [ parameter "DB_PASSWORD" (String password) ])
in
Azf_deploy.Az_cli.create config deployment
(* Ok [ ("hostName", "azf-example-app.azurewebsites.net"); ... ] *)
```

`Az_cli.validate`, `what_if` and `create_resource_group` take the same config. To use `az` directly instead, write the template with `Deployment.write_file "template.json" deployment`.

See [`docs/implementation-plan.md`](docs/implementation-plan.md) for the design and roadmap.

## Development

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune runtest                  # expect tests; accept changes with --auto-promote
dune exec examples/first_app.exe         # writes myFirstTemplate.json
dune exec examples/storage_account.exe   # writes storage_account.json
dune exec examples/web_app.exe           # writes web_app.json
DB_PASSWORD=... dune exec examples/deploy.exe -- my-rg westeurope
```
