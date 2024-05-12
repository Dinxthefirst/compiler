type binop =
  | Add
  | Sub
  | Mul
  | Div

type expr =
  | Int of int
  | BinOp of binop * expr * expr
