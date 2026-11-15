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

let to_string = function
  | East_us -> "eastus"
  | East_us_2 -> "eastus2"
  | Central_us -> "centralus"
  | North_central_us -> "northcentralus"
  | South_central_us -> "southcentralus"
  | West_central_us -> "westcentralus"
  | West_us -> "westus"
  | West_us_2 -> "westus2"
  | West_us_3 -> "westus3"
  | Canada_central -> "canadacentral"
  | Brazil_south -> "brazilsouth"
  | North_europe -> "northeurope"
  | West_europe -> "westeurope"
  | Uk_south -> "uksouth"
  | Uk_west -> "ukwest"
  | France_central -> "francecentral"
  | Germany_west_central -> "germanywestcentral"
  | Italy_north -> "italynorth"
  | Norway_east -> "norwayeast"
  | Poland_central -> "polandcentral"
  | Spain_central -> "spaincentral"
  | Sweden_central -> "swedencentral"
  | Switzerland_north -> "switzerlandnorth"
  | Uae_north -> "uaenorth"
  | South_africa_north -> "southafricanorth"
  | Central_india -> "centralindia"
  | East_asia -> "eastasia"
  | Southeast_asia -> "southeastasia"
  | Japan_east -> "japaneast"
  | Korea_central -> "koreacentral"
  | Australia_east -> "australiaeast"
  | Region name -> name

let to_expression t = Arm_expression.String (to_string t)
