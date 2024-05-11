
let rec eval = function
  | Ast.Int i -> i
  | Ast.Var v -> failwith ("Unbound variable: " ^ v)
  | Ast.Add (e1, e2) -> eval e1 + eval e2
  | Ast.Sub (e1, e2) -> eval e1 - eval e2
  | Ast.Mul (e1, e2) -> eval e1 * eval e2
  | Ast.Div (e1, e2) -> eval e1 / eval e2