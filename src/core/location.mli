(** Azure regions, for {!Azf_resources.Arm.location}. [Region] covers any region
    not listed, by its programmatic name, e.g. [Region "newzealandnorth"]. *)

type t =
  | East_us
  | East_us_2
  | Central_us
  | North_central_us
  | South_central_us
  | West_central_us
  | West_us
  | West_us_2
  | West_us_3
  | Canada_central
  | Brazil_south
  | North_europe
  | West_europe
  | Uk_south
  | Uk_west
  | France_central
  | Germany_west_central
  | Italy_north
  | Norway_east
  | Poland_central
  | Spain_central
  | Sweden_central
  | Switzerland_north
  | Uae_north
  | South_africa_north
  | Central_india
  | East_asia
  | Southeast_asia
  | Japan_east
  | Korea_central
  | Australia_east
  | Region of string

val to_string : t -> string
(** The programmatic name, e.g. ["northeurope"]. *)

val to_expression : t -> Arm_expression.t
(** {!to_string} as a literal [String]. *)
