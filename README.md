# azf

An OCaml port of [Farmer](https://compositionalit.github.io/farmer/): describe Azure resources with composable builders and emit ARM template JSON.

```ocaml
open Azf
open Azf_resources

let template =
  Storage_account.(build [ name "mystorage"; sku Standard_GRS; add_tag "env" "dev" ])
  |> Result.map (fun storage ->
         Deployment.(build [ add_resource (Storage_account.to_arm_resource storage) ])
         |> Deployment.to_string)
```

Builders validate their input, so `build` returns a `result` (e.g. storage account names must be 3–24 lowercase letters and digits). All builders share `Azf_resources.Error.t`, so they combine with `let*`.

See [`docs/implementation-plan.md`](docs/implementation-plan.md) for the design and roadmap.

## Development

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune runtest                  # expect tests; accept changes with --auto-promote
dune exec examples/storage_account.exe
dune exec examples/web_app.exe
```
