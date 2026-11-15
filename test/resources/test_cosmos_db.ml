open Azf
open Azf_resources

let print_result = function
  | Ok cosmos ->
      Cosmos_db.to_arm_resources cosmos
      |> List.iter (fun r -> print_endline (Arm_resource.to_string r))
  | Error e -> print_endline (Error.to_string e)

let print_error = function
  | Ok _ -> print_endline "ok"
  | Error e -> print_endline (Error.to_string e)

let orders =
  Cosmos_db.Container.(build [ name "orders"; partition_key [ "/customerId" ] ])
  |> Result.get_ok

let%expect_test "account defaults" =
  print_result Cosmos_db.(build [ name "mycosmos" ]);
  [%expect
    {|
    {
      "type": "Microsoft.DocumentDB/databaseAccounts",
      "apiVersion": "2025-04-15",
      "name": "mycosmos",
      "location": "[resourceGroup().location]",
      "kind": "GlobalDocumentDB",
      "properties": {
        "databaseAccountOfferType": "Standard",
        "consistencyPolicy": { "defaultConsistencyLevel": "Session" },
        "locations": [
          {
            "locationName": "[resourceGroup().location]",
            "failoverPriority": 0,
            "isZoneRedundant": false
          }
        ],
        "enableFreeTier": false
      }
    }
    |}]

let%expect_test "serverless account with a database and containers" =
  let events =
    Cosmos_db.Container.(
      build
        [
          name "events";
          partition_key [ "/tenantId"; "/userId" ];
          default_ttl 3600;
        ])
    |> Result.get_ok
  in
  let db =
    Cosmos_db.Database.(
      build [ name "shop"; add_container orders; add_container events ])
    |> Result.get_ok
  in
  print_result
    Cosmos_db.(
      build
        [
          name "mycosmos";
          consistency
            (Bounded_staleness
               { max_staleness_prefix = 100; max_interval_seconds = 5 });
          capacity_mode Serverless;
          free_tier true;
          add_database db;
          add_tag "team" "core";
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.DocumentDB/databaseAccounts",
      "apiVersion": "2025-04-15",
      "name": "mycosmos",
      "location": "[resourceGroup().location]",
      "tags": { "team": "core" },
      "kind": "GlobalDocumentDB",
      "properties": {
        "databaseAccountOfferType": "Standard",
        "consistencyPolicy": {
          "defaultConsistencyLevel": "BoundedStaleness",
          "maxStalenessPrefix": 100,
          "maxIntervalInSeconds": 5
        },
        "locations": [
          {
            "locationName": "[resourceGroup().location]",
            "failoverPriority": 0,
            "isZoneRedundant": false
          }
        ],
        "capabilities": [ { "name": "EnableServerless" } ],
        "enableFreeTier": true
      }
    }
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop",
      "properties": { "resource": { "id": "shop" } }
    }
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop/orders",
      "properties": {
        "resource": {
          "id": "orders",
          "partitionKey": {
            "paths": [ "/customerId" ],
            "kind": "Hash",
            "version": 2
          }
        }
      }
    }
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop/events",
      "properties": {
        "resource": {
          "id": "events",
          "partitionKey": {
            "paths": [ "/tenantId", "/userId" ],
            "kind": "MultiHash",
            "version": 2
          },
          "defaultTtl": 3600
        }
      }
    }
    |}]

let%expect_test "database throughput" =
  [ Cosmos_db.Throughput.Provisioned 400; Autoscale 4000 ]
  |> List.iter (fun t ->
      let db =
        Cosmos_db.Database.(build [ name "shop"; throughput t ])
        |> Result.get_ok
      in
      match Cosmos_db.(build [ name "mycosmos"; add_database db ]) with
      | Ok cosmos ->
          print_endline
            (Arm_resource.to_string
               (List.nth (Cosmos_db.to_arm_resources cosmos) 1))
      | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop",
      "properties": {
        "resource": { "id": "shop" },
        "options": { "throughput": 400 }
      }
    }
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop",
      "properties": {
        "resource": { "id": "shop" },
        "options": { "autoscaleSettings": { "maxThroughput": 4000 } }
      }
    }
    |}]

let%expect_test "deployment orders children with dependsOn" =
  let db =
    Cosmos_db.Database.(build [ name "shop"; add_container orders ])
    |> Result.get_ok
  in
  let cosmos =
    Cosmos_db.(build [ name "mycosmos"; add_database db ]) |> Result.get_ok
  in
  Deployment.build
    [
      Deployment.add_resources (Cosmos_db.to_arm_resources cosmos);
      Deployment.add_output
        (Output.string "endpoint" (Cosmos_db.endpoint cosmos));
      Deployment.add_output (Output.string "key" (Cosmos_db.primary_key cosmos));
      Deployment.add_output
        (Output.string "connection" (Cosmos_db.connection_string cosmos));
    ]
  |> Deployment.to_string |> print_endline;
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [
        {
          "type": "Microsoft.DocumentDB/databaseAccounts",
          "apiVersion": "2025-04-15",
          "name": "mycosmos",
          "location": "[resourceGroup().location]",
          "kind": "GlobalDocumentDB",
          "properties": {
            "databaseAccountOfferType": "Standard",
            "consistencyPolicy": { "defaultConsistencyLevel": "Session" },
            "locations": [
              {
                "locationName": "[resourceGroup().location]",
                "failoverPriority": 0,
                "isZoneRedundant": false
              }
            ],
            "enableFreeTier": false
          }
        },
        {
          "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases",
          "apiVersion": "2025-04-15",
          "name": "mycosmos/shop",
          "dependsOn": [
            "[resourceId('Microsoft.DocumentDB/databaseAccounts', 'mycosmos')]"
          ],
          "properties": { "resource": { "id": "shop" } }
        },
        {
          "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
          "apiVersion": "2025-04-15",
          "name": "mycosmos/shop/orders",
          "dependsOn": [
            "[resourceId('Microsoft.DocumentDB/databaseAccounts/sqlDatabases', 'mycosmos', 'shop')]"
          ],
          "properties": {
            "resource": {
              "id": "orders",
              "partitionKey": {
                "paths": [ "/customerId" ],
                "kind": "Hash",
                "version": 2
              }
            }
          }
        }
      ],
      "outputs": {
        "endpoint": {
          "type": "string",
          "value": "[reference(resourceId('Microsoft.DocumentDB/databaseAccounts', 'mycosmos')).documentEndpoint]"
        },
        "key": {
          "type": "string",
          "value": "[listKeys(resourceId('Microsoft.DocumentDB/databaseAccounts', 'mycosmos'), '2025-04-15').primaryMasterKey]"
        },
        "connection": {
          "type": "string",
          "value": "[listConnectionStrings(resourceId('Microsoft.DocumentDB/databaseAccounts', 'mycosmos'), '2025-04-15').connectionStrings[0].connectionString]"
        }
      }
    }
    |}]

let%expect_test "dedicated container throughput" =
  let dedicated =
    Cosmos_db.Container.(
      build
        [ name "hot"; partition_key [ "/id" ]; throughput (Provisioned 1000) ])
    |> Result.get_ok
  in
  let db =
    Cosmos_db.Database.(build [ name "shop"; add_container dedicated ])
    |> Result.get_ok
  in
  (match Cosmos_db.(build [ name "mycosmos"; add_database db ]) with
  | Ok cosmos ->
      print_endline
        (Arm_resource.to_string
           (List.nth (Cosmos_db.to_arm_resources cosmos) 2))
  | Error e -> print_endline (Error.to_string e));
  print_error
    Cosmos_db.(
      build [ name "mycosmos"; capacity_mode Serverless; add_database db ]);
  print_error
    Cosmos_db.Container.(
      build [ name "hot"; partition_key [ "/id" ]; throughput (Autoscale 1500) ]);
  [%expect
    {|
    {
      "type": "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers",
      "apiVersion": "2025-04-15",
      "name": "mycosmos/shop/hot",
      "properties": {
        "resource": {
          "id": "hot",
          "partitionKey": { "paths": [ "/id" ], "kind": "Hash", "version": 2 }
        },
        "options": { "throughput": 1000 }
      }
    }
    Cosmos DB "shop/hot" sets throughput, but the account is serverless
    Invalid Cosmos DB autoscale max throughput 1500 RU/s: must be at least 1000 and a multiple of 1000
    |}]

let%expect_test "account errors" =
  let shop = Cosmos_db.Database.(build [ name "shop" ]) |> Result.get_ok in
  let provisioned =
    Cosmos_db.Database.(build [ name "paid"; throughput (Provisioned 400) ])
    |> Result.get_ok
  in
  print_error (Cosmos_db.build []);
  print_error
    Cosmos_db.(build [ name "mycosmos"; add_database shop; add_database shop ]);
  print_error
    Cosmos_db.(
      build
        [ name "mycosmos"; capacity_mode Serverless; add_database provisioned ]);
  print_error
    Cosmos_db.(
      build
        [
          name "mycosmos";
          consistency
            (Bounded_staleness
               { max_staleness_prefix = 5; max_interval_seconds = 5 });
        ]);
  [%expect
    {|
    Cosmos DB account name is required
    Duplicate Cosmos DB database "shop"
    Cosmos DB "paid" sets throughput, but the account is serverless
    Invalid Cosmos DB bounded staleness (prefix 5, interval 5s): the prefix must be at least 10 and the interval 5-86400 seconds
    |}]

let%expect_test "account name rules" =
  [
    "ab";
    "abc";
    String.make 44 'a';
    String.make 45 'a';
    "-cosmos";
    "cosmos-";
    "My-Cosmos";
    "my_cosmos";
    "my-cosmos-1";
  ]
  |> List.iter (fun n -> print_error (Cosmos_db.validate_name n));
  [%expect
    {|
    Invalid Cosmos DB account name "ab": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    ok
    ok
    Invalid Cosmos DB account name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid Cosmos DB account name "-cosmos": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid Cosmos DB account name "cosmos-": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid Cosmos DB account name "My-Cosmos": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    Invalid Cosmos DB account name "my_cosmos": must be 3-44 characters, lowercase letters, digits and hyphens only, not starting or ending with a hyphen
    ok
    |}]

let%expect_test "database errors" =
  print_error (Cosmos_db.Database.build []);
  print_error Cosmos_db.Database.(build [ name "a/b" ]);
  print_error Cosmos_db.Database.(build [ name "shop " ]);
  print_error
    Cosmos_db.Database.(
      build [ name "shop"; add_container orders; add_container orders ]);
  [
    Cosmos_db.Throughput.Provisioned 300;
    Provisioned 450;
    Provisioned 1000;
    Autoscale 500;
    Autoscale 1500;
    Autoscale 2000;
  ]
  |> List.iter (fun t ->
      print_error Cosmos_db.Database.(build [ name "shop"; throughput t ]));
  [%expect
    {|
    Cosmos DB database name is required
    Invalid Cosmos DB database name "a/b": must be 1-255 characters, without / \ # ? and not ending with a space
    Invalid Cosmos DB database name "shop ": must be 1-255 characters, without / \ # ? and not ending with a space
    Duplicate Cosmos DB container "orders"
    Invalid Cosmos DB throughput 300 RU/s: must be at least 400 and a multiple of 100
    Invalid Cosmos DB throughput 450 RU/s: must be at least 400 and a multiple of 100
    ok
    Invalid Cosmos DB autoscale max throughput 500 RU/s: must be at least 1000 and a multiple of 1000
    Invalid Cosmos DB autoscale max throughput 1500 RU/s: must be at least 1000 and a multiple of 1000
    ok
    |}]

let%expect_test "container errors" =
  print_error Cosmos_db.Container.(build [ partition_key [ "/id" ] ]);
  print_error Cosmos_db.Container.(build [ name "orders" ]);
  print_error
    Cosmos_db.Container.(build [ name "o#1"; partition_key [ "/id" ] ]);
  [ [ "id" ]; [ "/" ]; [ "/a"; "/b"; "/c" ]; [ "/a"; "/b"; "/c"; "/d" ] ]
  |> List.iter (fun key ->
      print_error
        Cosmos_db.Container.(build [ name "orders"; partition_key key ]));
  [ -2; -1; 0; 1 ]
  |> List.iter (fun ttl ->
      print_error
        Cosmos_db.Container.(
          build [ name "orders"; partition_key [ "/id" ]; default_ttl ttl ]));
  [%expect
    {|
    Cosmos DB container name is required
    Cosmos DB container "orders" needs a partition key
    Invalid Cosmos DB container name "o#1": must be 1-255 characters, without / \ # ? and not ending with a space
    Invalid Cosmos DB partition key [id]: must be 1-3 paths, each starting with /
    Invalid Cosmos DB partition key [/]: must be 1-3 paths, each starting with /
    ok
    Invalid Cosmos DB partition key [/a; /b; /c; /d]: must be 1-3 paths, each starting with /
    Invalid Cosmos DB default TTL -2: must be -1 (no default) or at least 1 second
    ok
    Invalid Cosmos DB default TTL 0: must be -1 (no default) or at least 1 second
    ok
    |}]
