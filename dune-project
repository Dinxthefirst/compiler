(lang dune 3.15)

(name compiler)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Oliver Toft")

(maintainers "Oliver Toft")

(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name compiler)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
