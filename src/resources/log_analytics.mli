(** [Microsoft.OperationalInsights/workspaces], a Log Analytics workspace on the
    pay-as-you-go [PerGB2018] pricing tier. {!App_insights} stores its data in
    one.

    {[
      let logs = Log_analytics.(build [ name "my-logs"; retention_days 90 ])
      (* : (Log_analytics.t, Error.t) result *)
    ]} *)

type config = {
  name : string option;
  retention_days : int;
  daily_cap_gb : float option;
  location : Azf.Location.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated Log Analytics workspace. *)

val type_name : string
val api_version : string

val default : config
(** No name, 30 days retention, no daily cap, located in the resource group's
    location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 4–63 characters, letters, digits and hyphens, starting and
    ending with a letter or digit. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result.
    Retention must be 30–730 days and a daily cap a positive finite number. *)

val name : string -> config -> config
val retention_days : int -> config -> config

val daily_cap_gb : float -> config -> config
(** Stops ingestion for the day once this many GB have been ingested. *)

val location : Azf.Location.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val customer_id : t -> Azf.Arm_expression.t
(** The workspace ID (a GUID) used by agents to send data. *)

val to_arm_resource : t -> Azf.Arm_resource.t
