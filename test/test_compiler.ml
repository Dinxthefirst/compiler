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

let test_big_expression () =
  let code = "1 + 2 * 3 - 4 / 2" in
  let result = compile_and_evaluate code in
  let expected = "5" in
  check string "correct result" result expected
;;

let test_parentheses () =
  let code = "(1 + 2) * 3" in
  let result = compile_and_evaluate code in
  let expected = "9" in
  check string "correct result" result expected
;;

let test_negation () =
  let code = "-1" in
  let result = compile_and_evaluate code in
  let expected = "-1" in
  check string "correct result" result expected
;;

let test_negation_with_parentheses () =
  let code = "-(1 + 2)" in
  let result = compile_and_evaluate code in
  let expected = "-3" in
  check string "correct result" result expected
;;

let suite =
  [ "addition", `Quick, test_addition
  ; "subtraction", `Quick, test_subtraction
  ; "multiplication", `Quick, test_multiplication
  ; "division", `Quick, test_division
  ; "big expression", `Quick, test_big_expression
  ; "parentheses", `Quick, test_parentheses
  ; "negation", `Quick, test_negation
  ; "negation with parentheses", `Quick, test_negation_with_parentheses
  ]
;;

let () = Alcotest.run "Compiler" [ "Compile", suite ]
