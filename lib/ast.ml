type expr =
  | Int of int
  | Bool of bool
  | Var of string
  | BinOp of expr * binOp * expr
  | UnOp of unOp * expr
  | If of expr * expr * expr
  | Seq of expr * expr
  | ValDecl of string * expr
  | FunDecl of string * string * expr
  | Block of expr
  | Call of string * expr
  | Match of expr * case list

and binOp =
  | Add
  | Sub
  | Mul
  | Div
  | Mod
  | Pow
  | Eq
  | Neq
  | Lt
  | Lte
  | Gt
  | Gte
  | And
  | Or

and unOp =
  | Neg
  | Not

and case = int * expr

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
  | Seq (e1, e2) -> "Seq (" ^ string_of_ast e1 ^ ", " ^ string_of_ast e2 ^ ")"
  | ValDecl (s, e) -> "ValDecl (" ^ s ^ ", " ^ string_of_ast e ^ ")"
  | FunDecl (f, s, e) ->
    "FunDecl (" ^ f ^ ", " ^ s ^ ", " ^ string_of_ast e ^ ")"
  | Block e -> "Block {" ^ string_of_ast e ^ "}"
  | If (e1, e2, e3) ->
    "If ("
    ^ string_of_ast e1
    ^ ", "
    ^ string_of_ast e2
    ^ ", "
    ^ string_of_ast e3
    ^ ")"
  | Call (f, e) -> "FunCall (" ^ f ^ ", " ^ string_of_ast e ^ ")"
  | Match (e, c) -> "Match (" ^ string_of_ast e ^ ", " ^ string_of_case c ^ ")"

and string_of_binOp = function
  | Add -> "Add"
  | Sub -> "Sub"
  | Mul -> "Mul"
  | Div -> "Div"
  | Mod -> "Mod"
  | Pow -> "Pow"
  | Eq -> "Eq"
  | Neq -> "Neq"
  | Lt -> "Lt"
  | Lte -> "Lte"
  | Gt -> "Gt"
  | Gte -> "Gte"
  | And -> "And"
  | Or -> "Or"

and string_of_unOp = function
  | Neg -> "Neg"
  | Not -> "Not"

and string_of_case = function
  | cs ->
    List.fold_left
      (fun acc (c, e) ->
        acc ^ "(" ^ string_of_int c ^ ", " ^ string_of_ast e ^ ")")
      ""
      cs
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
  | Seq (d, e) -> pretty_string_of_ast d ^ ";\n" ^ pretty_string_of_ast e
  | ValDecl (s, e) -> "let " ^ s ^ " = " ^ pretty_string_of_ast e
  | FunDecl (f, s, e) -> "fn " ^ f ^ " " ^ s ^ " = " ^ pretty_string_of_ast e
  | Block e -> "{\n" ^ pretty_string_of_ast e ^ "\n}"
  | If (e1, e2, e3) ->
    "if "
    ^ pretty_string_of_ast e1
    ^ " then\n"
    ^ pretty_string_of_ast e2
    ^ "\nelse\n"
    ^ pretty_string_of_ast e3
  | Call (f, e) -> f ^ "(" ^ pretty_string_of_ast e ^ ")"
  | Match (e, c) ->
    "match " ^ pretty_string_of_ast e ^ " with " ^ pretty_string_of_case c

and pretty_string_of_binOp = function
  | Add -> "+"
  | Sub -> "-"
  | Mul -> "*"
  | Div -> "/"
  | Mod -> "%"
  | Pow -> "^"
  | Eq -> "=="
  | Neq -> "!="
  | Lt -> "<"
  | Lte -> "<="
  | Gt -> ">"
  | Gte -> ">="
  | And -> "&&"
  | Or -> "||"

and pretty_string_of_unOp = function
  | Neg -> "-"
  | Not -> "!"

and pretty_string_of_case = function
  | cs ->
    List.fold_left
      (fun acc (c, e) ->
        acc ^ "case " ^ string_of_int c ^ " => " ^ pretty_string_of_ast e ^ "\n")
      ""
      cs
;;
