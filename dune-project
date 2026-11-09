(lang dune 3.17)

(name azf)

(generate_opam_files true)

(license MIT)

(maintainers "Morten Knaack <knaack@gmail.com>")

(authors "Morten Knaack <knaack@gmail.com>")

(source
 (github mknaack/azf))

(package
 (name azf)
 (synopsis "OCaml DSL for generating Azure ARM templates")
 (description
  "An OCaml port of Farmer: build Azure resources with composable, type-safe builders and emit ARM template JSON.")
 (depends
  (ocaml
   (>= 4.14))
  dune
  (yojson
   (>= 2.0))
  (ppx_expect :with-test)
  (odoc :with-doc)
  (ocamlformat
   (and
    :with-dev-setup
    (= 0.28.1)))
  (ocaml-lsp-server :with-dev-setup)))
