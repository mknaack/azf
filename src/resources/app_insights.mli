(** [Microsoft.Insights/components], a workspace-based Application Insights
    resource. Classic (non-workspace) Application Insights is retired, so a
    {!Log_analytics} workspace is required.

    {[
      let ai = App_insights.(build [ name "my-ai"; workspace logs ])
      (* : (App_insights.t, Error.t) result *)
    ]}

    The workspace is recorded as an {!Azf.Arm_resource.t.references}, so
    {!Azf.Deployment.to_string} adds it to [dependsOn] when it is in the same
    deployment. Use {!connection_string} to connect an app, e.g. with
    {!Web_app.app_insights}. *)

type config = {
  name : string option;
  workspace : Log_analytics.t option;
  sampling_percentage : float option;
  disable_ip_masking : bool;
  location : Azf.Location.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated Application Insights resource. *)

val type_name : string
val api_version : string

val default : config
(** No name or workspace, no sampling (all telemetry kept), IP masking on,
    located in the resource group's location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 1–260 characters, none of [% & \ ? /] or control characters,
    not ending with a space or period. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result. A
    workspace is required, and a sampling percentage must be above 0 and at most
    100. *)

val name : string -> config -> config
val workspace : Log_analytics.t -> config -> config

val sampling_percentage : float -> config -> config
(** Keeps this percentage of telemetry, e.g. [25.]. *)

val disable_ip_masking : bool -> config -> config
(** Stores client IP addresses instead of masking them. *)

val location : Azf.Location.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val instrumentation_key : t -> Azf.Arm_expression.t
(** [reference(...).InstrumentationKey]. Prefer {!connection_string}. *)

val connection_string : t -> Azf.Arm_expression.t
(** [reference(...).ConnectionString], for
    [APPLICATIONINSIGHTS_CONNECTION_STRING]. *)

val to_arm_resource : t -> Azf.Arm_resource.t
