open Azf

let print_json json = print_endline (Yojson.Safe.pretty_to_string json)
let print_expr e = print_endline (Arm_expression.to_string e)
let site = Resource_id.make ~type_name:"Microsoft.Web/sites" "myapp"

let%expect_test "literal strings" =
  print_expr (String "plain");
  print_expr (String "[not an expression]");
  print_expr (String "");
  [%expect {|
    plain
    [[not an expression]
    |}]

let%expect_test "expressions" =
  print_expr (Parameters "appName");
  print_expr (Variables "prefix");
  print_expr (Resource_id site);
  print_expr (Property (Reference site, "defaultHostName"));
  print_expr (Concat [ String "https://"; Parameters "host"; Int 443 ]);
  print_expr
    (Call ("uniqueString", [ Property (Call ("resourceGroup", []), "id") ]));
  print_expr (Call ("if", [ Bool true; String "it's"; Bool false ]));
  print_expr Arm_expression.resource_group_location;
  [%expect
    {|
    [parameters('appName')]
    [variables('prefix')]
    [resourceId('Microsoft.Web/sites', 'myapp')]
    [reference(resourceId('Microsoft.Web/sites', 'myapp')).defaultHostName]
    [concat('https://', parameters('host'), 443)]
    [uniqueString(resourceGroup().id)]
    [if(true(), 'it''s', false())]
    [resourceGroup().location]
    |}]

let%expect_test "expression json" =
  print_json
    (`List
       Arm_expression.
         [
           yojson_of_t (Int 1);
           yojson_of_t (Bool false);
           yojson_of_t (String "x");
           yojson_of_t (Parameters "p");
         ]);
  [%expect {| [ 1, false, "x", "[parameters('p')]" ] |}]

let%expect_test "resource id equality" =
  Printf.printf "%b %b %b\n"
    (Resource_id.equal site
       (Resource_id.make ~type_name:"Microsoft.Web/sites" "myapp"))
    (Resource_id.equal site
       (Resource_id.make ~type_name:"Microsoft.Web/sites" "other"))
    (Resource_id.equal site
       (Resource_id.make ~type_name:"Microsoft.Web/serverfarms" "myapp"));
  [%expect {| true false false |}]

let minimal_resource : Arm_resource.t =
  {
    type_name = "Microsoft.Web/serverfarms";
    api_version = "2022-09-01";
    name = "myplan";
    location = None;
    tags = [];
    sku = None;
    kind = None;
    depends_on = [];
    properties = `Assoc [];
  }

let%expect_test "minimal resource omits optional fields" =
  print_json (Arm_resource.yojson_of_t minimal_resource);
  [%expect
    {|
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "myplan",
      "properties": {}
    }
    |}]

let%expect_test "full resource" =
  print_json
    (Arm_resource.yojson_of_t
       {
         minimal_resource with
         location = Some (String "westeurope");
         tags = [ ("env", "dev"); ("team", "core") ];
         sku = Some (Sku.make ~tier:"Standard" "S1");
         kind = Some "app";
         depends_on = [ site ];
       });
  [%expect
    {|
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "myplan",
      "location": "westeurope",
      "tags": { "env": "dev", "team": "core" },
      "sku": { "name": "S1", "tier": "Standard" },
      "kind": "app",
      "dependsOn": [ "[resourceId('Microsoft.Web/sites', 'myapp')]" ],
      "properties": {}
    }
    |}]

let%expect_test "resource id of resource" =
  let id = Arm_resource.resource_id minimal_resource in
  print_endline (Resource_id.type_name id ^ " " ^ Resource_id.name id);
  [%expect {| Microsoft.Web/serverfarms myplan |}]

let%expect_test "empty deployment" =
  print_json (Deployment.emit Deployment.empty);
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {},
      "resources": [],
      "outputs": {}
    }
    |}]

let%expect_test "deployment with parameters, resources and outputs" =
  let deployment =
    Deployment.build
      [
        Deployment.add_parameter (Parameter.string ~default:"myapp" "appName");
        Deployment.add_parameter (Parameter.secure_string "adminPassword");
        Deployment.add_parameter (Parameter.int ~default:2 "instances");
        Deployment.add_parameter (Parameter.bool ~default:true "enabled");
        Deployment.add_parameter (Parameter.int "port");
        Deployment.add_resources [ minimal_resource ];
        Deployment.add_resource { minimal_resource with name = "second" };
        Deployment.add_output
          (Output.string "host" (Property (Reference site, "defaultHostName")));
        Deployment.add_output
          (Output.int "count"
             (Parameter.to_expression (Parameter.int "instances")));
        Deployment.add_output (Output.bool "on" (Parameters "enabled"));
      ]
  in
  print_json (Deployment.emit deployment);
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "appName": { "type": "string", "defaultValue": "myapp" },
        "adminPassword": { "type": "securestring" },
        "instances": { "type": "int", "defaultValue": 2 },
        "enabled": { "type": "bool", "defaultValue": true },
        "port": { "type": "int" }
      },
      "resources": [
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "myplan",
          "properties": {}
        },
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "second",
          "properties": {}
        }
      ],
      "outputs": {
        "host": {
          "type": "string",
          "value": "[reference(resourceId('Microsoft.Web/sites', 'myapp')).defaultHostName]"
        },
        "count": { "type": "int", "value": "[parameters('instances')]" },
        "on": { "type": "bool", "value": "[parameters('enabled')]" }
      }
    }
    |}]

let%expect_test "sku omits unset fields" =
  print_json (Sku.yojson_of_t (Sku.make "Standard_LRS"));
  print_json
    (Sku.yojson_of_t
       (Sku.make ~tier:"Standard" ~size:"S1" ~family:"S" ~capacity:2 "S1"));
  [%expect
    {|
    { "name": "Standard_LRS" }
    {
      "name": "S1",
      "tier": "Standard",
      "size": "S1",
      "family": "S",
      "capacity": 2
    }
    |}]
