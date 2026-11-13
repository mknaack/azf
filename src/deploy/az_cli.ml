open Ppx_yojson_conv_lib.Yojson_conv.Primitives
open Azf

module Mode = struct
  type t = Incremental | Complete

  let to_string = function
    | Incremental -> "Incremental"
    | Complete -> "Complete"
end

module Error = struct
  type t =
    | Az_not_found of string
    | Failed of { exit_code : int; stderr : string }
    | Unexpected_output of string

  let to_string = function
    | Az_not_found az ->
        Printf.sprintf "could not run %s; is the Azure CLI installed?" az
    | Failed { exit_code; stderr } ->
        Printf.sprintf "az exited with code %d: %s" exit_code
          (String.trim stderr)
    | Unexpected_output output -> "unexpected output from az: " ^ output
end

module Config = struct
  type t = {
    az : string;
    resource_group : string;
    name : string;
    mode : Mode.t;
    parameters : (string * Parameter.Value.t) list;
  }

  let build ~az ~resource_group ~name transformers =
    List.fold_left
      (fun c f -> f c)
      { az; resource_group; name; mode = Incremental; parameters = [] }
      transformers

  let mode mode c = { c with mode }

  let parameter key value c =
    { c with parameters = c.parameters @ [ (key, value) ] }
end

module Action = struct
  type t = Validate | What_if | Create

  let to_string = function
    | Validate -> "validate"
    | What_if -> "what-if"
    | Create -> "create"

  (* what-if prints a readable report; create's JSON holds the outputs. *)
  let output_args = function
    | Validate -> [ "--output"; "none" ]
    | What_if -> []
    | Create -> [ "--output"; "json" ]
end

let ( let* ) = Result.bind

type value = Parameter.Value.t

let yojson_of_value = Parameter.Value.yojson_of_t

type parameter_value = { value : value } [@@deriving yojson_of]
type parameter_values = (string * parameter_value) list

let yojson_of_parameter_values values =
  `Assoc (List.map (fun (key, v) -> (key, yojson_of_parameter_value v)) values)

type parameters_file = {
  schema : string; [@key "$schema"]
  content_version : string; [@key "contentVersion"]
  parameters : parameter_values;
}
[@@deriving yojson_of]

let parameters_file_contents values =
  yojson_of_parameters_file
    {
      schema =
        "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#";
      content_version = "1.0.0.0";
      parameters = List.map (fun (key, value) -> (key, { value })) values;
    }
  |> Yojson.Safe.pretty_to_string

let remove path = try Sys.remove path with Sys_error _ -> ()

let with_temp_file suffix f =
  let path = Filename.temp_file "azf" suffix in
  Fun.protect ~finally:(fun () -> remove path) (fun () -> f path)

let write_file path contents =
  Out_channel.with_open_text path (fun oc ->
      Out_channel.output_string oc contents)

let read_file path = In_channel.with_open_text path In_channel.input_all

let spawn az args ~stdout ~stderr =
  let open_out path = Unix.openfile path [ O_WRONLY; O_TRUNC ] 0o600 in
  let fd_out = open_out stdout in
  let fd_err = open_out stderr in
  Fun.protect
    ~finally:(fun () ->
      Unix.close fd_out;
      Unix.close fd_err)
    (fun () ->
      match
        Unix.create_process az
          (Array.of_list (az :: args))
          Unix.stdin fd_out fd_err
      with
      | pid -> Ok pid
      | exception Unix.Unix_error ((ENOENT | EACCES), _, _) ->
          Error (Error.Az_not_found az))

(* Output goes to files rather than pipes, so a chatty az cannot block. *)
let run az args =
  with_temp_file ".out" @@ fun stdout ->
  with_temp_file ".err" @@ fun stderr ->
  let* pid = spawn az args ~stdout ~stderr in
  match snd (Unix.waitpid [] pid) with
  | WEXITED 0 -> Ok (read_file stdout)
  | WEXITED 127 -> Error (Error.Az_not_found az)
  | WEXITED exit_code | WSIGNALED exit_code | WSTOPPED exit_code ->
      Error (Error.Failed { exit_code; stderr = read_file stderr })

let with_parameters_file (c : Config.t) f =
  match c.parameters with
  | [] -> f []
  | values ->
      with_temp_file ".json" @@ fun path ->
      write_file path (parameters_file_contents values);
      f [ "--parameters"; "@" ^ path ]

let deployment_args action (c : Config.t) ~template =
  [
    "deployment";
    "group";
    Action.to_string action;
    "--resource-group";
    c.resource_group;
    "--name";
    c.name;
    "--template-file";
    template;
    "--mode";
    Mode.to_string c.mode;
  ]

let run_deployment action (c : Config.t) deployment =
  with_temp_file ".json" @@ fun template ->
  Deployment.write_file template deployment;
  with_parameters_file c @@ fun parameter_args ->
  run c.az
    (deployment_args action c ~template
    @ parameter_args @ Action.output_args action)

let validate c deployment =
  run_deployment Validate c deployment |> Result.map ignore

let what_if c deployment = run_deployment What_if c deployment

let output_value = function
  | `String s -> s
  | json -> Yojson.Safe.to_string json

let outputs_of_json output =
  let open Yojson.Safe.Util in
  match
    Yojson.Safe.from_string output
    |> member "properties" |> member "outputs" |> to_option to_assoc
    |> Option.value ~default:[]
    |> List.map (fun (key, o) -> (key, output_value (member "value" o)))
  with
  | outputs -> Ok outputs
  | exception (Yojson.Json_error _ | Type_error _) ->
      Error (Error.Unexpected_output output)

let create c deployment =
  let* output = run_deployment Create c deployment in
  outputs_of_json output

let create_resource_group (c : Config.t) ~location =
  run c.az
    [
      "group";
      "create";
      "--name";
      c.resource_group;
      "--location";
      location;
      "--output";
      "none";
    ]
  |> Result.map ignore
