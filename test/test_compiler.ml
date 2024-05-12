open Alcotest
open Compiler.Compile

let test_addition () =
  let code = "1 + 2" in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let test_subtraction () =
  let code = "10 - 5" in
  let result = compile_and_evaluate code in
  let expected = "5" in
  check string "correct result" result expected
;;

let test_multiplication () =
  let code = "3 * 4" in
  let result = compile_and_evaluate code in
  let expected = "12" in
  check string "correct result" result expected
;;

let test_division () =
  let code = "10 / 2" in
  let result = compile_and_evaluate code in
  let expected = "5" in
  check string "correct result" result expected
;;

let suite =
  [ "addition", `Quick, test_addition
  ; "subtraction", `Quick, test_subtraction
  ; "multiplication", `Quick, test_multiplication
  ; "division", `Quick, test_division
  ]
;;

let () = Alcotest.run "Compiler" [ "Compile", suite ]
