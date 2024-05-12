type op =
  | Add
  | Sub
  | Mul
  | Div

type expr =
  | Int of int
  | BinOp of expr * op * expr
