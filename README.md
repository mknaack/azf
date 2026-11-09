# azf

An OCaml port of [Farmer](https://compositionalit.github.io/farmer/): describe Azure resources with composable builders and emit ARM template JSON.

```ocaml
open Azf
open Azf_resources

let storage =
  Storage_account.(build [ name "mystorage"; sku Standard_GRS; add_tag "env" "dev" ])

let template =
  Deployment.(build [ add_resource (Storage_account.to_arm_resource storage) ])
  |> Deployment.emit |> Yojson.Safe.pretty_to_string
```

See [`docs/implementation-plan.md`](docs/implementation-plan.md) for the design and roadmap.

## Development

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune runtest                  # expect tests; accept changes with --auto-promote
dune exec examples/storage_account.exe
```
