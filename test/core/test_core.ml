open Azf

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
  print_expr (Parameter (Parameter.string "appName"));
  print_expr (Variables "prefix");
  print_expr (Resource_id site);
  print_expr (Property (Reference site, "defaultHostName"));
  print_expr
    (Concat [ String "https://"; Parameter (Parameter.string "host"); Int 443 ]);
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
    references = [];
    parameters = [];
    properties = `Assoc [];
  }

let%expect_test "minimal resource omits optional fields" =
  print_endline (Arm_resource.to_string minimal_resource);
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
  print_endline
    (Arm_resource.to_string
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
  print_endline (Deployment.to_string Deployment.empty);
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
          (Output.int "count" (Parameter (Parameter.int "instances")));
        Deployment.add_output
          (Output.bool "on" (Parameter (Parameter.bool "enabled")));
      ]
  in
  print_endline (Deployment.to_string deployment);
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

let%expect_test "parameter options" =
  let open Parameter in
  print_endline
    (Deployment.to_string
       (Deployment.build
          [
            Deployment.add_parameter
              (string ~default:"B1" ~allowed:[ "B1"; "S1" ]
                 ~description:"Plan size" "size");
            Deployment.add_parameter
              (secure_string ~min_length:12 ~max_length:64 "password");
            Deployment.add_parameter (int ~min_value:1 ~max_value:10 "count");
            Deployment.add_parameter
              (array ~default:[ String "a"; Int 1 ] ~min_length:1 "items");
            Deployment.add_parameter
              (object_
                 ~default:[ ("enabled", Bool true); ("tags", Array []) ]
                 "settings");
            Deployment.add_parameter (secure_object "secrets");
          ]));
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "size": {
          "type": "string",
          "defaultValue": "B1",
          "allowedValues": [ "B1", "S1" ],
          "metadata": { "description": "Plan size" }
        },
        "password": { "type": "securestring", "minLength": 12, "maxLength": 64 },
        "count": { "type": "int", "minValue": 1, "maxValue": 10 },
        "items": { "type": "array", "defaultValue": [ "a", 1 ], "minLength": 1 },
        "settings": {
          "type": "object",
          "defaultValue": { "enabled": true, "tags": [] }
        },
        "secrets": { "type": "secureObject" }
      },
      "resources": [],
      "outputs": {}
    }
    |}]

let%expect_test "parameters used in expressions are added to the template" =
  let location = Parameter.string ~default:"westeurope" "location" in
  let name = Parameter.string "name" in
  let resource =
    {
      minimal_resource with
      location = Some (Parameter location);
      parameters = Arm_expression.parameters (Parameter location);
    }
  in
  print_endline
    (Deployment.to_string
       (Deployment.build
          [
            Deployment.add_parameter (Parameter.string ~default:"first" "name");
            Deployment.add_resource resource;
            Deployment.add_output
              (Output.string "both"
                 (Concat [ Parameter name; Parameter location ]));
            Deployment.add_output
              (Output.array "list" (Call ("array", [ Parameter name ])));
          ]));
  [%expect
    {|
    {
      "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
      "contentVersion": "1.0.0.0",
      "parameters": {
        "name": { "type": "string", "defaultValue": "first" },
        "location": { "type": "string", "defaultValue": "westeurope" }
      },
      "resources": [
        {
          "type": "Microsoft.Web/serverfarms",
          "apiVersion": "2022-09-01",
          "name": "myplan",
          "location": "[parameters('location')]",
          "properties": {}
        }
      ],
      "outputs": {
        "both": {
          "type": "string",
          "value": "[concat(parameters('name'), parameters('location'))]"
        },
        "list": { "type": "array", "value": "[array(parameters('name'))]" }
      }
    }
    |}]

let%expect_test "sku omits unset fields" =
  let print_sku sku =
    print_endline
      (Arm_resource.to_string { minimal_resource with sku = Some sku })
  in
  print_sku (Sku.make "Standard_LRS");
  print_sku (Sku.make ~tier:"Standard" ~size:"S1" ~family:"S" ~capacity:2 "S1");
  [%expect
    {|
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "myplan",
      "sku": { "name": "Standard_LRS" },
      "properties": {}
    }
    {
      "type": "Microsoft.Web/serverfarms",
      "apiVersion": "2022-09-01",
      "name": "myplan",
      "sku": {
        "name": "S1",
        "tier": "Standard",
        "size": "S1",
        "family": "S",
        "capacity": 2
      },
      "properties": {}
    }
    |}]
