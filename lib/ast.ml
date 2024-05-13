type expr =
  | Int of int
  | BinOp of expr * binOp * expr
  | UnOp of unOp * expr
  | Var of var
  | Decl of var * expr
  | Seq of expr * expr

and binOp =
  | Add
  | Sub
  | Mul
  | Div
  | Mod

and unOp = Neg
and var = string

let rec string_of_ast = function
  | Int i -> "Int (" ^ string_of_int i ^ ")"
  | BinOp (e1, op, e2) ->
    "BinOp ("
    ^ string_of_ast e1
    ^ ", "
    ^ string_of_binOp op
    ^ ", "
    ^ string_of_ast e2
    ^ ")"
  | UnOp (op, e) -> "UnOp (" ^ string_of_unOp op ^ ", " ^ string_of_ast e ^ ")"
  | Var v -> "Var \"" ^ v ^ "\""
  | Decl (v, e) -> "Decl (\"" ^ v ^ "\", " ^ string_of_ast e ^ ")"
  | Seq (e1, e2) -> "Seq (" ^ string_of_ast e1 ^ ", " ^ string_of_ast e2 ^ ")"

and string_of_binOp = function
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Mod -> "Mod"

and string_of_unOp = function
  | Neg -> "Neg"
;;

let rec pretty_string_of_ast = function
  | Int i -> string_of_int i
  | BinOp (e1, op, e2) ->
    "("
    ^ pretty_string_of_ast e1
    ^ " "
    ^ pretty_string_of_binOp op
    ^ " "
    ^ pretty_string_of_ast e2
    ^ ")"
  | UnOp (op, e) -> pretty_string_of_unOp op ^ pretty_string_of_ast e
  | Var v -> v
  | Decl (v, e) -> "val " ^ v ^ " = " ^ pretty_string_of_ast e
  | Seq (e1, e2) -> pretty_string_of_ast e1 ^ ";\n" ^ pretty_string_of_ast e2

and pretty_string_of_binOp = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"

and pretty_string_of_unOp = function
  | Neg -> "-"
;;
