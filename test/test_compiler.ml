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

let test_exponentiation () =
  let code = "3^3" in
  let result = compile_and_evaluate code in
  let expected = "27" in
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
  let code = "let x = 2; x" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_multiple_semicolons () =
  let code = "let x = 2; let y = 1; x + y" in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let test_declaration () =
  let code = "let x = 2; x" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_multiple_declarations () =
  let code = "let x = 2; let y = 3; x + y" in
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
    "{ let x = -1; let y = 1; let z = { let a = 45; let b = 24; a + b }; x + y \
     + z }"
  in
  let result = compile_and_evaluate code in
  let expected = "69" in
  check string "correct result" result expected
;;

let test_bool () =
  let code = "true" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_if () =
  let code = "if true then 1 else 2" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_if_else () =
  let code = "if false then 1 else 2" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_equals () =
  let code = "1 == 1" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_not_equals () =
  let code = "1 != 1" in
  let result = compile_and_evaluate code in
  let expected = "0" in
  check string "correct result" result expected
;;

let test_greater_than () =
  let code = "2 > 1" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_greater_than_equals () =
  let code = "2 >= 2" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_and () =
  let code = "true && false" in
  let result = compile_and_evaluate code in
  let expected = "0" in
  check string "correct result" result expected
;;

let test_or () =
  let code = "true || false" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_less_than () =
  let code = "1 < 2" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_less_than_equals () =
  let code = "3 <= 2" in
  let result = compile_and_evaluate code in
  let expected = "0" in
  check string "correct result" result expected
;;

let test_not () =
  let code = "!true" in
  let result = compile_and_evaluate code in
  let expected = "0" in
  check string "correct result" result expected
;;

let test_big_not () =
  let code = "!(!true)" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_big_if_else () =
  let code =
    "if { let x = 1; x == 1 } then { if 2 <= 2 then 69 else 2 } else 3"
  in
  let result = compile_and_evaluate code in
  let expected = "69" in
  check string "correct result" result expected
;;

let test_bigger_expression () =
  let code =
    "{ \n\
    \  let x = {\n\
    \    let a = 100 * 1;\n\
    \    let b = 1;\n\
    \    if false then b else {\n\
    \      a + b\n\
    \    }\n\
    \  };\n\
    \  let y = -(!(0));\n\
    \  let z = (1 < 2) + 1;\n\
    \  let w = (true + true) * (true + true);\n\
    \  let v = (10 % 3 - true) * false;\n\
    \  x + y + z + w + v \n\
    \ }"
    (* x = 101
       y = -1
       z = 2
       w = 4
       v = 0
       res = 106 *)
  in
  let result = compile_and_evaluate code in
  let expected = "106" in
  check string "correct result" result expected
;;

let test_match () =
  let code = "match 1 with case 1 => 1 end" in
  let result = compile_and_evaluate code in
  let expected = "1" in
  check string "correct result" result expected
;;

let test_big_match () =
  let code =
    "match 3 with case 1 => 1 case 2 => 2 case 3 => 3 case 4 => 4 case 5 => 5 \
     end"
  in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let test_function () =
  let code = "fn f(x) = x + 1; f(1)" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_multiple_functions () =
  let code = "fn f(x) = x + 1; fn g(x) = x + 2; f(1) + g(1)" in
  let result = compile_and_evaluate code in
  let expected = "5" in
  check string "correct result" result expected
;;

let test_function_multiple_args () =
  let code = "fn f(x, y) = x + y; f(1, 2)" in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let test_function_with_function_call () =
  let code = "fn f(x) = x + 1; fn g(x) = f(x); g(1)" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_function_block () =
  let code = "fn f(x) = {x + 1}; f(1)" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_function_within_function () =
  let code = "fn f(x) = {fn g(y) = x + y; g(1)}; f(1)" in
  let result = compile_and_evaluate code in
  let expected = "2" in
  check string "correct result" result expected
;;

let test_recursion () =
  let code = "fn f(x) = if x == 0 then 0 else f(x - 1); f(10)" in
  let result = compile_and_evaluate code in
  let expected = "0" in
  check string "correct result" result expected
;;

let test_function_currying () =
  let code = "fn f(x) = fn g(y) = x + y; f(1)(2)" in
  let result = compile_and_evaluate code in
  let expected = "3" in
  check string "correct result" result expected
;;

let suite =
  [ "addition", `Quick, test_addition
  ; "subtraction", `Quick, test_subtraction
  ; "multiplication", `Quick, test_multiplication
  ; "division", `Quick, test_division
  ; "modulo", `Quick, test_modulo
  ; "exponentiation", `Quick, test_exponentiation
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
  ; "bool", `Quick, test_bool
  ; "if", `Quick, test_if
  ; "if else", `Quick, test_if_else
  ; "equals", `Quick, test_equals
  ; "not equals", `Quick, test_not_equals
  ; "less than", `Quick, test_less_than
  ; "less than equals", `Quick, test_less_than_equals
  ; "greater than", `Quick, test_greater_than
  ; "greater than equals", `Quick, test_greater_than_equals
  ; "and", `Quick, test_and
  ; "or", `Quick, test_or
  ; "not", `Quick, test_not
  ; "big not", `Quick, test_big_not
  ; "big if else", `Quick, test_big_if_else
  ; "bigger expression", `Quick, test_bigger_expression
  ; "match", `Quick, test_match
  ; "big match", `Quick, test_big_match
  ; "function", `Quick, test_function
  ; "multiple functions", `Quick, test_multiple_functions
  ; "function multiple args", `Quick, test_function_multiple_args
  ; "function with function call", `Quick, test_function_with_function_call
  ; "function block", `Quick, test_function_block
  ; "function within function", `Quick, test_function_within_function
  ; "recursion", `Quick, test_recursion
  ; "function currying", `Quick, test_function_currying
  ]
;;

let () = Alcotest.run "Compiler" [ "Compile", suite ]
