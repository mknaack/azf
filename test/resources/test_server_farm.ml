open Azf
open Azf_resources

let print_result = function
  | Ok farm ->
      print_endline (Arm_resource.to_string (Server_farm.to_arm_resource farm))
  | Error e -> print_endline (Error.to_string e)

let%expect_test "defaults" =
  print_result Server_farm.(build [ name "myplan" ]);
  [%expect
    {|
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "myplan",
      "location": "[resourceGroup().location]",
      "sku": { "name": "F1", "tier": "Free", "capacity": 1 },
      "kind": "app",
      "properties": { "reserved": false }
    }
    |}]

let%expect_test "linux premium with tags and dependency" =
  let other =
    Resource_id.make ~type_name:"Microsoft.Network/virtualNetworks" "vnet"
  in
  print_result
    Server_farm.(
      build
        [
          name "my-plan";
          sku P1v3;
          os Linux;
          capacity 3;
          location (String "westeurope");
          add_tag "env" "prod";
          depends_on other;
        ]);
  [%expect
    {|
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "my-plan",
      "location": "westeurope",
      "tags": { "env": "prod" },
      "sku": { "name": "P1v3", "tier": "PremiumV3", "capacity": 3 },
      "kind": "linux",
      "dependsOn": [
        "[resourceId('Microsoft.Network/virtualNetworks', 'vnet')]"
      ],
      "properties": { "reserved": true }
    }
    |}]

let%expect_test "validation" =
  [
    Server_farm.build [];
    Server_farm.(build [ name "" ]);
    Server_farm.(build [ name "a" ]);
    Server_farm.(build [ name (String.make 60 'a') ]);
    Server_farm.(build [ name (String.make 61 'a') ]);
    Server_farm.(build [ name "my_plan" ]);
    Server_farm.(build [ name "My-Plan-01" ]);
    Server_farm.(build [ name "myplan"; capacity 0 ]);
  ]
  |> List.iter (function
    | Ok farm ->
        print_endline ("ok " ^ Resource_id.name (Server_farm.resource_id farm))
    | Error e -> print_endline (Error.to_string e));
  [%expect
    {|
    Server farm name is required
    Invalid server farm name "": must be 1-60 characters, letters, digits and hyphens only
    ok a
    ok aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    Invalid server farm name "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": must be 1-60 characters, letters, digits and hyphens only
    Invalid server farm name "my_plan": must be 1-60 characters, letters, digits and hyphens only
    ok My-Plan-01
    Invalid server farm capacity 0: must be at least 1
    |}]
