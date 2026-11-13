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
    | Missing_resource_group
    | Az_not_found of string
    | Failed of { exit_code : int; stderr : string }
    | Unexpected_output of string

  let to_string = function
    | Missing_resource_group -> "no resource group set"
    | Az_not_found az ->
        Printf.sprintf "could not run %s; is the Azure CLI installed?" az
    | Failed { exit_code; stderr } ->
        Printf.sprintf "az exited with code %d: %s" exit_code
          (String.trim stderr)
    | Unexpected_output output -> "unexpected output from az: " ^ output
end

type config = {
  resource_group : string option;
  name : string;
  mode : Mode.t;
  parameters : (string * Parameter.Value.t) list;
  az : string;
}

let default =
  {
    resource_group = None;
    name = "azf";
    mode = Incremental;
    parameters = [];
    az = "az";
  }

let resource_group rg c = { c with resource_group = Some rg }
let name name c = { c with name }
let mode mode c = { c with mode }

let parameter key value c =
  { c with parameters = c.parameters @ [ (key, value) ] }

let az az c = { c with az }
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

let run az args =
  with_temp_file ".out" @@ fun out ->
  with_temp_file ".err" @@ fun err ->
  let open_out path = Unix.openfile path [ O_WRONLY; O_TRUNC ] 0o600 in
  let fd_out = open_out out in
  let fd_err = open_out err in
  let started =
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
  in
  let* pid = started in
  match snd (Unix.waitpid [] pid) with
  | WEXITED 0 -> Ok (read_file out)
  | WEXITED 127 -> Error (Error.Az_not_found az)
  | WEXITED exit_code | WSIGNALED exit_code | WSTOPPED exit_code ->
      Error (Error.Failed { exit_code; stderr = read_file err })

let configure transformers =
  let c = List.fold_left (fun c f -> f c) default transformers in
  match c.resource_group with
  | Some rg -> Ok (c, rg)
  | None -> Error Error.Missing_resource_group

let with_parameters_file (c : config) f =
  match c.parameters with
  | [] -> f []
  | values ->
      with_temp_file ".json" @@ fun path ->
      write_file path (parameters_file_contents values);
      f [ "--parameters"; "@" ^ path ]

let run_deployment action extra_args transformers deployment =
  let* c, rg = configure transformers in
  with_temp_file ".json" @@ fun template ->
  Deployment.write_file template deployment;
  with_parameters_file c @@ fun parameter_args ->
  run c.az
    ([
       "deployment";
       "group";
       action;
       "--resource-group";
       rg;
       "--name";
       c.name;
       "--template-file";
       template;
       "--mode";
       Mode.to_string c.mode;
     ]
    @ parameter_args @ extra_args)

let validate transformers deployment =
  run_deployment "validate" [ "--output"; "none" ] transformers deployment
  |> Result.map ignore

let what_if transformers deployment =
  run_deployment "what-if" [] transformers deployment

let outputs_of_json output =
  let unexpected = Error (Error.Unexpected_output output) in
  match Yojson.Safe.from_string output with
  | exception Yojson.Json_error _ -> unexpected
  | `Assoc fields -> (
      match List.assoc_opt "properties" fields with
      | Some (`Assoc properties) -> (
          match List.assoc_opt "outputs" properties with
          | None | Some `Null -> Ok []
          | Some (`Assoc outputs) ->
              Ok
                (List.map
                   (fun (key, output) ->
                     let value =
                       match output with
                       | `Assoc o -> List.assoc_opt "value" o
                       | _ -> None
                     in
                     ( key,
                       match value with
                       | Some (`String s) -> s
                       | Some json -> Yojson.Safe.to_string json
                       | None -> "null" ))
                   outputs)
          | Some _ -> unexpected)
      | _ -> unexpected)
  | _ -> unexpected

let create transformers deployment =
  let* output =
    run_deployment "create" [ "--output"; "json" ] transformers deployment
  in
  outputs_of_json output

let create_resource_group transformers ~location =
  let* c, rg = configure transformers in
  run c.az
    [
      "group";
      "create";
      "--name";
      rg;
      "--location";
      location;
      "--output";
      "none";
    ]
  |> Result.map ignore
