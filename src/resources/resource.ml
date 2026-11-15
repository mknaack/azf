type 'state t = {
  state : 'state;
  emit : location:Azf.Arm_expression.t -> Azf.Arm_resource.t list;
}

let make state emit = { state; emit }
let state t = t.state

let to_arm_resources ?(location = Azf.Arm_expression.resource_group_location) t
    =
  t.emit ~location
