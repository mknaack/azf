type t = { type_name : string; name : string }

let make ~type_name name = { type_name; name }
let type_name t = t.type_name
let name t = t.name

let equal a b =
  String.equal a.type_name b.type_name && String.equal a.name b.name
