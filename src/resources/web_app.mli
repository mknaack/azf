(** [Microsoft.Web/sites], an App Service web app hosted on a {!Server_farm}.

    {[
      let app =
        Web_app.(
          build
            [
              name "myapp"; service_plan plan; add_setting "ENV" (String "dev");
            ])
      (* : (Web_app.t, Web_app.Error.t) result *)
    ]}

    The app depends on its server farm automatically. *)

module Error : sig
  type t = Missing_name | Invalid_name of string | Missing_service_plan

  val to_string : t -> string
end

type config = {
  name : string option;
  service_plan : Server_farm.t option;
  https_only : bool;
  always_on : bool;
  app_settings : (string * Azf.Arm_expression.t) list;
  location : Azf.Arm_expression.t;
  tags : (string * string) list;
  depends_on : Azf.Resource_id.t list;
}
(** Builder state. Turned into a validated {!t} by {!build}. *)

type t
(** A validated web app. *)

val type_name : string
val api_version : string

val default : config
(** No name or service plan, HTTPS only, [always_on] off (the [F1] tier does not
    support it), no app settings, located in the resource group's location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 2–60 characters, letters, digits and hyphens, not starting or
    ending with a hyphen. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result. *)

val name : string -> config -> config
val service_plan : Server_farm.t -> config -> config
val https_only : bool -> config -> config
val always_on : bool -> config -> config

val add_setting : string -> Azf.Arm_expression.t -> config -> config
(** Adds an app setting; a later setting with the same name replaces an earlier
    one. *)

val add_settings : (string * Azf.Arm_expression.t) list -> config -> config
val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val default_host_name : t -> Azf.Arm_expression.t
(** [reference(resourceId('Microsoft.Web/sites', 'name')).defaultHostName] *)

val to_arm_resource : t -> Azf.Arm_resource.t
