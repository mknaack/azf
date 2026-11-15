type t =
  | Resource_group
  | East_asia
  | Southeast_asia
  | Central_us
  | East_us
  | East_us_2
  | West_us
  | West_us_2
  | West_us_3
  | North_central_us
  | South_central_us
  | North_europe
  | West_europe
  | Japan_west
  | Japan_east
  | Brazil_south
  | Australia_east
  | Australia_southeast
  | South_india
  | Central_india
  | West_india
  | Canada_central
  | Canada_east
  | Uk_south
  | Uk_west
  | West_central_us
  | Korea_central
  | Korea_south
  | France_central
  | France_south
  | Australia_central
  | Australia_central_2
  | Uae_central
  | Uae_north
  | South_africa_north
  | South_africa_west
  | Sweden_central
  | Sweden_south
  | Switzerland_north
  | Switzerland_west
  | Germany_north
  | Germany_west_central
  | Germany_central
  | Germany_northeast
  | Norway_west
  | Norway_east
  | Brazil_southeast
  | China_north
  | China_east
  | China_north_2
  | China_north_3
  | China_east_2
  | China_east_3
  | Qatar_central
  | Us_dod_central
  | Us_dod_east
  | Us_gov_arizona
  | Us_gov_texas
  | Us_gov_virginia
  | Us_gov_iowa
  | Israel_central
  | Italy_north
  | Poland_central
  | Mexico_central
  | Spain_central
  | Indonesia_central
  | New_zealand_north
  | Malaysia_west
  | Denmark_east
  | Region of string
  | Parameter of Parameter.t

let to_expression : t -> Arm_expression.t = function
  | Resource_group -> Arm_expression.resource_group_location
  | East_asia -> String "eastasia"
  | Southeast_asia -> String "southeastasia"
  | Central_us -> String "centralus"
  | East_us -> String "eastus"
  | East_us_2 -> String "eastus2"
  | West_us -> String "westus"
  | West_us_2 -> String "westus2"
  | West_us_3 -> String "westus3"
  | North_central_us -> String "northcentralus"
  | South_central_us -> String "southcentralus"
  | North_europe -> String "northeurope"
  | West_europe -> String "westeurope"
  | Japan_west -> String "japanwest"
  | Japan_east -> String "japaneast"
  | Brazil_south -> String "brazilsouth"
  | Australia_east -> String "australiaeast"
  | Australia_southeast -> String "australiasoutheast"
  | South_india -> String "southindia"
  | Central_india -> String "centralindia"
  | West_india -> String "westindia"
  | Canada_central -> String "canadacentral"
  | Canada_east -> String "canadaeast"
  | Uk_south -> String "uksouth"
  | Uk_west -> String "ukwest"
  | West_central_us -> String "westcentralus"
  | Korea_central -> String "koreacentral"
  | Korea_south -> String "koreasouth"
  | France_central -> String "francecentral"
  | France_south -> String "francesouth"
  | Australia_central -> String "australiacentral"
  | Australia_central_2 -> String "australiacentral2"
  | Uae_central -> String "uaecentral"
  | Uae_north -> String "uaenorth"
  | South_africa_north -> String "southafricanorth"
  | South_africa_west -> String "southafricawest"
  | Sweden_central -> String "swedencentral"
  | Sweden_south -> String "swedensouth"
  | Switzerland_north -> String "switzerlandnorth"
  | Switzerland_west -> String "switzerlandwest"
  | Germany_north -> String "germanynorth"
  | Germany_west_central -> String "germanywestcentral"
  | Germany_central -> String "germanycentral"
  | Germany_northeast -> String "germanynortheast"
  | Norway_west -> String "norwaywest"
  | Norway_east -> String "norwayeast"
  | Brazil_southeast -> String "brazilsoutheast"
  | China_north -> String "chinanorth"
  | China_east -> String "chinaeast"
  | China_north_2 -> String "chinanorth2"
  | China_north_3 -> String "chinanorth3"
  | China_east_2 -> String "chinaeast2"
  | China_east_3 -> String "chinaeast3"
  | Qatar_central -> String "qatarcentral"
  | Us_dod_central -> String "usdodcentral"
  | Us_dod_east -> String "usdodeast"
  | Us_gov_arizona -> String "usgovarizona"
  | Us_gov_texas -> String "usgovtexas"
  | Us_gov_virginia -> String "usgovvirginia"
  | Us_gov_iowa -> String "usgoviowa"
  | Israel_central -> String "israelcentral"
  | Italy_north -> String "italynorth"
  | Poland_central -> String "polandcentral"
  | Mexico_central -> String "mexicocentral"
  | Spain_central -> String "spaincentral"
  | Indonesia_central -> String "indonesiacentral"
  | New_zealand_north -> String "newzealandnorth"
  | Malaysia_west -> String "malaysiawest"
  | Denmark_east -> String "denmarkeast"
  | Region name -> String name
  | Parameter p -> Parameter p
