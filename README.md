# azf

An OCaml port of [Farmer](https://compositionalit.github.io/farmer/): describe Azure resources with composable builders and emit ARM template JSON.

```ocaml
open Azf
open Azf_resources

let template =
  Storage_account.(build [ name "mystorage"; sku Standard_GRS; location West_europe; add_tag "env" "dev" ])
  |> Result.map (fun storage ->
         Deployment.(build [ add_resource (Storage_account.to_arm_resource storage) ])
         |> Deployment.to_string)
```

Builders validate their input, so `build` returns a `result` (e.g. storage account names must be 3–24 lowercase letters and digits). All builders share `Azf_resources.Error.t`, so they combine with `let*`.

Dependencies and parameters are worked out from the expressions resources use: a web app whose settings use a storage account's connection string gets that account in its `dependsOn`, and `Web_app.add_secret_setting "DB_PASSWORD"` adds a `securestring` parameter to the template.

## Resources

| Module | ARM type |
| --- | --- |
| `Storage_account` | `Microsoft.Storage/storageAccounts` |
| `Server_farm` | `Microsoft.Web/serverfarms` |
| `Web_app` | `Microsoft.Web/sites` |
| `Log_analytics` | `Microsoft.OperationalInsights/workspaces` |
| `App_insights` | `Microsoft.Insights/components` (workspace-based) |
| `Cosmos_db` | `Microsoft.DocumentDB/databaseAccounts` (NoSQL), with `sqlDatabases` and `containers` |

```ocaml
let* logs = Log_analytics.(build [ name "my-logs" ]) in
let* ai = App_insights.(build [ name "my-ai"; workspace logs ]) in
let* app = Web_app.(build [ name "myapp"; service_plan plan; app_insights ai ]) in
let* orders = Cosmos_db.Container.(build [ name "orders"; partition_key [ "/customerId" ] ]) in
let* shop = Cosmos_db.Database.(build [ name "shop"; throughput (Autoscale 1000); add_container orders ]) in
let* cosmos = Cosmos_db.(build [ name "mycosmos"; add_database shop ]) in
(* Deployment.add_resources (Cosmos_db.to_arm_resources cosmos) *)
```

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
dune exec examples/storage_account.exe
dune exec examples/web_app.exe
DB_PASSWORD=... dune exec examples/web_app.exe -- deploy my-rg westeurope
```
