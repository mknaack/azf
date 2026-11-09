# OCaml Farmer (azf) Implementation Plan

Farmer is an F# DSL that generates Azure ARM/Bicep JSON templates from composable, type-safe resource builders. This document outlines the steps to build an OCaml equivalent.

## 1. Architecture overview

Replicate Farmer's three layers:

- **Resource builders** — F# computation expressions like `webApp { name "x"; sku S1 }` that collect config into a record. In OCaml, use transformer functions: each builder takes a list of `config -> config` functions, e.g. `Web_app.build [ name "myapp"; sku S1 ]`.
- **Resource interface** — each builder emits one or more `Arm_resource.t` values (type name + JSON body + dependencies).
- **Deployment builder** — aggregates resources, parameters, outputs, and serializes to an ARM template JSON (`$schema`, `resources[]`, `parameters`, `outputs`).

## 2. Project skeleton

- `dune-project` + opam files, mirroring the structure of `mknaack/azure-cosmos-db` (core package, optional extras).
- JSON: `yojson` for hand-written serializers, or `atdgen` for schema-driven ARM resource types.
- DSL style: `config -> config` transformer lists (closest OCaml analogue to F# computation expressions). Prototype this on one resource before committing, since it determines the ergonomics of the whole library.

## 3. Core engine (build first, before any Azure resources)

- `Arm_resource.t` — `{ type_name; api_version; name; properties : Yojson.Safe.t; depends_on; location; tags }`.
- `Deployment.t` — collection of resources + parameters + outputs.
- `emit : Deployment.t -> Yojson.Safe.t` producing a valid ARM template (`https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#`).
- `Arm_expression` AST for ARM template functions (`resourceId`, `concat`, `reference`, `parameters`, `variables`) that serializes to `"[resourceId('Microsoft.Web/sites', name)]"` strings.

## 4. Resources (incremental)

Start with 2–3 resources to validate the design:

- `Microsoft.Storage/storageAccounts`
- `Microsoft.Web/serverfarms` + `Microsoft.Web/sites` (Farmer's canonical example, proves dependencies)

Each resource module: a `config` record with defaults, transformer functions (`name`, `sku`, `add_tags`, `depends_on`), and a `to_arm_resource` function. Use a typed `ResourceId` for cross-resource references so `depends_on` isn't stringly-typed.

## 5. Parameters, outputs, secrets

- `parameter` support: values hoisted into the template's `parameters` block, with `secureString` for secrets (Farmer's `SecureParameter`).
- `output` values referencing `reference()` expressions.

## 6. Deployment path

- Shell out to `az deployment group create` (simplest, matches Farmer).
- Optionally later: call the ARM REST API directly using HTTP machinery patterned on `azure-cosmos-db` (Cohttp + TLS). Note ARM uses AAD bearer tokens, not Cosmos master-key signing.

## 7. Testing

- Golden/snapshot tests: builder → expected JSON template.
- Validation: emitted templates pass `az deployment group validate` or the ARM template schema.

## 8. Later enhancements

- Bicep emission in addition to JSON.
- `depends_on` inference from `resourceId` references.
- Location/tag inheritance from deployment level down to resources.

## Milestone order

1. Core engine + storage account
2. Web app + server farm (proves dependencies)
3. Parameters/outputs
4. CLI deploy
5. Broaden resource coverage
