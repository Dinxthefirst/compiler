type expr =
  | Int of int
  | BinOp of expr * binOp * expr
  | UnOp of unOp * expr
  | Var of string
  | Decl of var * expr

and binOp =
  | Add
  | Sub
  | Mul
  | Div
  | Mod

and unOp = Neg
and var = string

let rec string_of_ast = function
  | Int i -> string_of_int i
  | BinOp (e1, op, e2) ->
    "(" ^ string_of_ast e1 ^ " " ^ string_of_binOp op ^ " " ^ string_of_ast e2 ^ ")"
  | UnOp (op, e) -> string_of_unOp op ^ string_of_ast e
  | Var v -> v
  | Decl (v, e) -> "val " ^ v ^ " = " ^ string_of_ast e

and string_of_binOp = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"

and string_of_unOp = function
  | Neg -> "-"
;;
