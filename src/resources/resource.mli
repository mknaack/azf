(** A validated resource, as returned by every builder's [build], e.g.
    [Web_app.t = Web_app.state Resource.t]. ['state] is the builder's own data,
    which only that builder's module can use; {!to_arm_resources} works on any
    resource, which is what lets {!Arm.add_resource} take them all. *)

type 'state t

val make :
  'state ->
  (location:Azf.Arm_expression.t -> Azf.Arm_resource.t list) ->
  'state t
(** [make state emit]. [emit ~location] produces the ARM resources, using
    [location] for those whose builder was given no [location]. For builders. *)

val state : 'state t -> 'state

val to_arm_resources :
  ?location:Azf.Arm_expression.t -> _ t -> Azf.Arm_resource.t list
(** [location] defaults to {!Azf.Arm_expression.resource_group_location}. *)
