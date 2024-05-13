type expr =
  | Int of int
  | Bool of bool
  | BinOp of expr * binOp * expr
  | UnOp of unOp * expr
  | Var of var
  | Decl of var * expr
  | If of expr * expr * expr
  | Seq of expr * expr (* should be decl * expr *)
  | Block of expr

and binOp =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Eq
  | Lt
  | Lte

and unOp = Neg
and var = string

let rec string_of_ast = function
  | Int i -> "Int (" ^ string_of_int i ^ ")"
  | Bool b -> "Bool (" ^ string_of_bool b ^ ")"
  | Var v -> "Var \"" ^ v ^ "\""
  | BinOp (e1, op, e2) ->
    "BinOp ("
    ^ string_of_ast e1
    ^ ", "
    ^ string_of_binOp op
    ^ ", "
    ^ string_of_ast e2
    ^ ")"
  | UnOp (op, e) -> "UnOp (" ^ string_of_unOp op ^ ", " ^ string_of_ast e ^ ")"
  | Decl (v, e) -> "Decl (\"" ^ v ^ "\", " ^ string_of_ast e ^ ")"
  | Seq (e1, e2) -> "Seq (" ^ string_of_ast e1 ^ ", " ^ string_of_ast e2 ^ ")"
  | Block e -> "Block {" ^ string_of_ast e ^ "}"
  | If (e1, e2, e3) ->
    "If ("
    ^ string_of_ast e1
    ^ ", "
    ^ string_of_ast e2
    ^ ", "
    ^ string_of_ast e3
    ^ ")"

and string_of_binOp = function
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Mod -> "Mod"
  | Eq -> "Eq"
  | Lt -> "Lt"
  | Lte -> "Lte"

and string_of_unOp = function
  | Neg -> "Neg"
;;

let rec pretty_string_of_ast = function
  | Int i -> string_of_int i
  | Bool b -> string_of_bool b
  | Var v -> v
  | BinOp (e1, op, e2) ->
    "("
    ^ pretty_string_of_ast e1
    ^ " "
    ^ pretty_string_of_binOp op
    ^ " "
    ^ pretty_string_of_ast e2
    ^ ")"
  | UnOp (op, e) -> pretty_string_of_unOp op ^ pretty_string_of_ast e
  | Decl (v, e) -> "val " ^ v ^ " = " ^ pretty_string_of_ast e
  | Seq (e1, e2) -> pretty_string_of_ast e1 ^ ";\n" ^ pretty_string_of_ast e2
  | Block e -> "{\n" ^ pretty_string_of_ast e ^ "\n}"
  | If (e1, e2, e3) ->
    "if "
    ^ pretty_string_of_ast e1
    ^ " then\n"
    ^ pretty_string_of_ast e2
    ^ "\nelse\n"
    ^ pretty_string_of_ast e3

and pretty_string_of_binOp = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"
  | Eq -> "=="
  | Lt -> "<"
  | Lte -> "<="

and pretty_string_of_unOp = function
  | Neg -> "-"
;;
