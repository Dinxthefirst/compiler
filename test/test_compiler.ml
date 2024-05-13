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

let test_modulo () =
  let code = "10 % 3" in
  let result = compile_and_evaluate code in
  let expected = "1" in
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

let test_semicolon () =
  let code = "1; 2" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_multiple_semicolons () =
  let code = "1; 2; 3" in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let test_declaration () =
  let code = "val x = 2; x" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_multiple_declarations () =
  let code = "val x = 2; val y = 3; x + y" in
  let result = compile_and_evaluate code in
  let expected = "5" in
  check string "correct result" result expected
;;

let test_block () =
  let code = "{ 2 }" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_big_block () =
  let code =
    "{ val x = -1; val y = 1; val z = { val a = 45; val b = 24; a + b }; x + y \
     + z }"
  in
  let result = compile_and_evaluate code in
  let expected = "69" in
  check string "correct result" result expected
;;

let suite =
  [ "addition", `Quick, test_addition
  ; "subtraction", `Quick, test_subtraction
  ; "multiplication", `Quick, test_multiplication
  ; "division", `Quick, test_division
  ; "modulo", `Quick, test_modulo
  ; "big expression", `Quick, test_big_expression
  ; "parentheses", `Quick, test_parentheses
  ; "negation", `Quick, test_negation
  ; "negation with parentheses", `Quick, test_negation_with_parentheses
  ; "semicolon", `Quick, test_semicolon
  ; "multiple semicolons", `Quick, test_multiple_semicolons
  ; "declaration", `Quick, test_declaration
  ; "multiple declarations", `Quick, test_multiple_declarations
  ; "block", `Quick, test_block
  ; "big block", `Quick, test_big_block
  ]
;;

let () = Alcotest.run "Compiler" [ "Compile", suite ]
