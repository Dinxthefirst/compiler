open Ast
module VarEnv = Map.Make (String)
module FunEnv = Map.Make (String)

type closure = string list * expr * var_env
and var_env = int VarEnv.t

type env =
  { var_env : var_env
  ; fun_env : closure FunEnv.t
  }

let rec evaluate_expr env = function
  | Int i -> env, i
  | Bool b -> env, if b then 1 else 0
  | Var x ->
    (try env, VarEnv.find x env.var_env with
     | Not_found -> failwith ("Unbound variable: " ^ x))
  | BinOp (e1, op, e2) ->
    let env', v1 = evaluate_expr env e1 in
    let env'', v2 = evaluate_expr env' e2 in
    ( env''
    , (match op with
       | Add -> v1 + v2
       | Sub -> v1 - v2
       | Mul -> v1 * v2
       | Div -> v1 / v2
       | Mod -> v1 mod v2
       | Pow -> int_of_float (float_of_int v1 ** float_of_int v2)
       | Eq -> if v1 = v2 then 1 else 0
       | Neq -> if v1 <> v2 then 1 else 0
       | Lt -> if v1 < v2 then 1 else 0
       | Lte -> if v1 <= v2 then 1 else 0
       | Gt -> if v1 > v2 then 1 else 0
       | Gte -> if v1 >= v2 then 1 else 0
       | And -> if v1 = 1 && v2 = 1 then 1 else 0
       | Or -> if v1 = 1 || v2 = 1 then 1 else 0) )
  | UnOp (op, e) ->
    let env', v = evaluate_expr env e in
    ( env'
    , (match op with
       | Neg -> -v
       | Not -> if v = 0 then 1 else 0) )
  | ValDecl (x, e) ->
    let env', v = evaluate_expr env e in
    { env' with var_env = VarEnv.add x v env'.var_env }, v
  | FunDecl (f, xs, e) ->
    let closure = xs, e, env.var_env in
    { env with fun_env = FunEnv.add f closure env.fun_env }, 0
  | Seq (d, e) ->
    let env', _ = evaluate_expr env d in
    evaluate_expr env' e
  | Block e -> evaluate_expr env e
  | If (cond, e1, e2) ->
    let env', v = evaluate_expr env cond in
    (match v with
     | 1 -> evaluate_expr env' e1
     | 0 -> evaluate_expr env' e2
     | _ -> failwith "Invalid condition")
  | Match (e, cases) ->
    let _, v = evaluate_expr env e in
    let rec match_cases env = function
      | [] -> failwith "No matching case"
      | (c, e) :: cs ->
        let _, v' = evaluate_expr env c in
        if v = v' then evaluate_expr env e else match_cases env cs
    in
    match_cases env cases
  | Call (f, args) ->
    let closure = FunEnv.find f env.fun_env in
    let xs, e, var_env = closure in
    let rec bind_args env xs args =
      match xs, args with
      | [], [] -> env
      | x :: xs, arg :: args ->
        let _, v = evaluate_expr env arg in
        let new_var_env = VarEnv.add x v env.var_env in
        bind_args { env with var_env = new_var_env } xs args
      | _ -> failwith "Invalid number of arguments"
    in
    let env' = bind_args { env with var_env } xs args in
    evaluate_expr env' e
;;

let evaluate expr =
  let env = { var_env = VarEnv.empty; fun_env = FunEnv.empty } in
  let _, value = evaluate_expr env expr in
  string_of_int value
;;
