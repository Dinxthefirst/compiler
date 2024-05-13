open Ast
module VarMap = Map.Make (String)

let rec evaluate_expr env = function
  | Int i -> env, i
  | Bool b -> env, if b then 1 else 0
  | Var x ->
    (try env, VarMap.find x env with
     | Not_found -> failwith ("Unbound variable: " ^ x))
  | BinOp (e1, op, e2) ->
    let env', v1 = evaluate_expr env e1 in
    let env'', v2 = evaluate_expr env' e2 in
    (match op with
     | Add -> env'', v1 + v2
     | Sub -> env'', v1 - v2
     | Mul -> env'', v1 * v2
     | Div -> env'', v1 / v2
     | Mod -> env'', v1 mod v2
     | Eq -> env'', if v1 = v2 then 1 else 0
     | Lt -> env'', if v1 < v2 then 1 else 0
     | Lte -> env'', if v1 <= v2 then 1 else 0)
  | UnOp (op, e) ->
    let env', v = evaluate_expr env e in
    (match op with
     | Neg -> env', -v)
  | Decl (x, e) ->
    let env, v = evaluate_expr env e in
    let env' = VarMap.add x v env in
    evaluate_expr env' e
  | Seq (e1, e2) ->
    let env', _ = evaluate_expr env e1 in
    evaluate_expr env' e2
  | Block e -> evaluate_expr env e
  | If (cond, e1, e2) ->
    let env', v = evaluate_expr env cond in
    (match v with
     | 1 -> evaluate_expr env' e1
     | 0 -> evaluate_expr env' e2
     | _ -> failwith "Invalid condition")
;;

let evaluate expr =
  let env : int VarMap.t = VarMap.empty in
  let _, value = evaluate_expr env expr in
  string_of_int value
;;
