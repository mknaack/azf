open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type t = {
  name : string;
  tier : string option; [@yojson.option]
  size : string option; [@yojson.option]
  family : string option; [@yojson.option]
  capacity : int option; [@yojson.option]
}
[@@deriving yojson_of]

let make ?tier ?size ?family ?capacity name =
  { name; tier; size; family; capacity }
