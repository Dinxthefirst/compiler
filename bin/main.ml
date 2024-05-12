open Compiler.Compile

let () = print_endline (compile_and_evaluate Sys.argv.(1))
