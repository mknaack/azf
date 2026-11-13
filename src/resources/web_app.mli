(** [Microsoft.Web/sites], an App Service web app hosted on a {!Server_farm}.

    {[
      let app =
        Web_app.(
          build
            [
              name "myapp"; service_plan plan; add_setting "ENV" (String "dev");
            ])
      (* : (Web_app.t, Error.t) result *)
    ]}

    The server farm and any resources used in app settings are recorded as
    {!Azf.Arm_resource.t.references}, so {!Azf.Deployment.to_string} adds them
    to [dependsOn] when they are in the same deployment. *)

module Runtime : sig
  (** The version is passed through as App Service expects it for the plan's OS,
      e.g. [Dotnet "8.0"], [Node "20-lts"], [Java "17-java17"] on Linux and
      [Dotnet "v8.0"], [Node "~20"], [Java "17"] on Windows. *)
  type t =
    | Dotnet of string
    | Node of string
    | Python of string
    | Java of string
    | Php of string

  val to_string : t -> string
  (** The Linux [linuxFxVersion] form, e.g. ["DOTNETCORE|8.0"]. *)
end

type config = {
  name : string option;
  service_plan : Server_farm.t option;
  https_only : bool;
  always_on : bool;
  runtime : Runtime.t option;
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
(** No name, service plan or runtime, HTTPS only, [always_on] off (the [F1] tier
    does not support it), no app settings, located in the resource group's
    location. *)

val validate_name : string -> (string, Error.t) result
(** Azure's rule: 2–60 characters, letters, digits and hyphens, not starting or
    ending with a hyphen. *)

val build : (config -> config) list -> (t, Error.t) result
(** Applies the transformers to {!default} in order and validates the result. *)

val name : string -> config -> config
val service_plan : Server_farm.t -> config -> config
val https_only : bool -> config -> config
val always_on : bool -> config -> config

val runtime : Runtime.t -> config -> config
(** Sets [linuxFxVersion] on Linux plans, or the matching [netFrameworkVersion]
    / [nodeVersion] / [phpVersion] / [javaVersion] on Windows. Python is only
    available on Linux plans. *)

val add_setting : string -> Azf.Arm_expression.t -> config -> config
(** Adds an app setting; a later setting with the same name replaces an earlier
    one. *)

val add_settings : (string * Azf.Arm_expression.t) list -> config -> config

val add_secret_setting : string -> config -> config
(** [add_secret_setting "DB_PASSWORD"] sets the app setting to a [securestring]
    parameter with the same name, so the value is supplied at deployment time
    instead of being stored in the template. *)

val location : Azf.Arm_expression.t -> config -> config
val add_tag : string -> string -> config -> config
val add_tags : (string * string) list -> config -> config
val depends_on : Azf.Resource_id.t -> config -> config
val resource_id : t -> Azf.Resource_id.t

val default_host_name : t -> Azf.Arm_expression.t
(** [reference(resourceId('Microsoft.Web/sites', 'name')).defaultHostName] *)

val to_arm_resource : t -> Azf.Arm_resource.t
