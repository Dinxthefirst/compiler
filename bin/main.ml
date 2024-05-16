open Compiler.Compile

let () =
  print_endline "Welcome to the ScalaML compiler!";
  print_endline "Compiling...";
  print_endline (compile_and_evaluate Sys.argv.(1))
;;
