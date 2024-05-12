type op =
  | Add
  | Sub
  | Mul
  | Div

type unop = Neg

type expr =
  | Int of int
  | BinOp of expr * op * expr
  | UnOp of unop * expr

let rec string_of_ast = function
  | Int i -> string_of_int i
  | BinOp (e1, op, e2) ->
    "(" ^ string_of_ast e1 ^ " " ^ string_of_op op ^ " " ^ string_of_ast e2 ^ ")"
  | UnOp (op, e) -> "(" ^ string_of_unop op ^ string_of_ast e ^ ")"

and string_of_op = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"

and string_of_unop = function
  | Neg -> "-"
;;
