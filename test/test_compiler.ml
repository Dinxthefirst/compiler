let test_cases = [ "1 + 2"; "10 - 5"; "2 * 3"; "10 / 2" ]

let () =
  List.iter
    (fun expr ->
      let result = Compiler.Compile.compile_and_evaulate expr in
      Printf.printf "%s -> %s\n" expr result)
    test_cases
;;
