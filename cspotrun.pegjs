{ 
  pegedit_opts = {treenav:"collapse"};
  
  symbol_table = {};

  var traverse_program = function(ast) {
    return_val = [];
    
    if (ast.children) {
      for (var stmt in ast.children) {
        return_val.push(traverse(ast.children[stmt]));
      }
    }
    return return_val.join('');
  };
  var traverse_initialize = function(ast) {
    symbol_table[ast.child_objs["id"]] = { "type": ast.child_objs["typename"], "val": traverse(ast.child_objs["value"])};
  };
  var traverse_declare = function(ast) {
    symbol_table[ast.child_objs["id"]] = { "type": ast.child_objs["typename"]};
  }
  var traverse_add = function(ast) {
    return traverse(ast.child_objs["left"]) + 
      traverse(ast.child_objs["right"]);
  };
  var traverse_number = function(ast) {
    return ast.name
  };
  traverse = function(ast) {
    if (ast.construct) {
      switch (ast.construct) {
        case "program"    : return traverse_program(ast);
        case "initialize" : return traverse_initialize(ast);
        case "declare"    : return traverse_declare(ast);
        case "add"        : return traverse_add(ast);
        case "number"     : return traverse_number(ast);
        default: console.error(ast);
      }
    }
  };
}
// Grammar:

program        = stmts:statement* { return {construct: "program", name: "program", children: stmts}; }

statement      = stmt:(label_stmt
                  / goto_stmt
                  / declare_stmt
                  / assign_stmt
                  / ifthen_stmt
                  / loop_stmt
                  / print_stmt) WSNL { return stmt; }

/* * * * * * * * * * * * * * * * * * 
 * GOTO CONSTRUCTS                 *
 * * * * * * * * * * * * * * * * * */

// Target of goto statements.
label_stmt     = l:label { return {construct: "label_stmt", name: l.name}; }

// Used in label_stmt and goto_stmt.
label          = LESS i:ID GREATER { return i; }

// Transfer flow of control to the node of the tree with the given label.
goto_stmt      = GOTO l:label { return { name: "goto", child_objs: {label: l}, children: [l]}; }

/* * * * * * * * * * * * * * * * * * 
 * VARIABLE HANDLING CONSTRUCTS    *
 * * * * * * * * * * * * * * * * * */

declare_stmt   = initialize
               / declare

initialize   = t:typename WS i:ID a:assign_pred { return { construct: "initialize", name: "initialize", child_objs: {typename: t.name, id: i.name, value: a}, children: [t, i, a]};}

declare = t:typename WS i:ID { return { construct: "declare", name: "declare", child_objs: {typename: t.name, id: i.name}, children: [t, i]}; }

assign_pred    = ASSIGN_OP e:expr { return e; }

assign_stmt    = list_itm_assign 
               / scalar_assign

list_itm_assign= LET li:list_itm EQUALS e:expr { return { construct: "assign", name: "assign", child_objs: {list_item: li, value: e}, children: [li, e]};}

scalar_assign  = LET i:ID ASSIGN_OP e:expr { return {construct: "assign", name: "assign", child_objs: {id: i.name, value: e.name}, children: [i, e]}; }


/* CONDITIONAL EXECUTION CONSTRUCTS */
// If-then construct
ifthen_stmt    = ip:if_part tp:then_part end_if { return { construct: "if-then", name: "if-then", children: [ip, tp]};}

if_part        = IF cond:bool_expr COLON WSNL{ return {construct: "cond", name: "cond", child_objs: {condition: cond}, children: [cond]};}

then_part      = stmts:statement* { return {construct: "program", name: "then part", children: stmts};}

end_if         = END IF 

// Loop construct
loop_stmt      = lh:loop_header lb:loop_body el:end_loop { return {construct: "loop_stmt", name: "loop", child_objs: {header: lh, body: lb}, children: [lh, lb]}; }

loop_header    = WHILE cond:bool_expr COLON WSNL{ return {construct: "cond", name: "cond", child_objs: {condition: cond}, children: [cond]}; }

loop_body      = stmts:statement* { return {construct: "program", name: "loop body", children:  stmts}; }

end_loop       = REPEAT

/* I/O CONSTRUCTS */
print_stmt     = PRINT e:expr { return { construct: "print_stmt", name: "print", child_objs: {expression: e}, children: [e]}; }

/* * * * * * * * * * * * * * * * * * 
 * EXPRESSIONS                     *
 * * * * * * * * * * * * * * * * * */

// Arithmetic expressions:
//   Left associative operations are refactored into 
//   commutative operations algebraically. (Subract => add a negative,
//   divide => multiply by reciprocal).
expr           = add

add            = l:subtract PLUS r:add { return { construct: "add", name: "+", child_objs: {left: l, right: r}, children:[l, r]}; }
               / subtract
 
subtract       = l:neg r:subtract { return {construct: "add", name: '+', child_objs: {left: l, right: r}, children: [l, r]};}
               / neg
               
               // Little hack here to display negatives, instead of more complicated tree.  
neg            = MINUS n:mult { return {construct: "negative", name: '-' + n.name} ;}
               / mult
 
mult           = l:div TIMES r:mult { return {construct: "multiply", name: "*", child_objs: {left: l, right: r}, children: [l, r]}; }
               / div
 
div            = num:recip denom:div { return {construct: "multiply", name: '*', child_objs: {numerator: num, denominator: denom}, children: [num, denom]}; }
               / recip
 
               // Little hack here to display reciprocals, instead of more complicated tree. 
recip          = DIVIDE n:number { return {construct: "reciprocal", name: "1/" + n.name}; }
               / parens
 
parens         = OPEN_PAREN a:add CLOSE_PAREN { return a; }
               / number
               
number         = n:num_lit { return {construct: "number", name: n}; }
               / num_var

num_lit        = f:float { return parseFloat(f); }
               / i:integer { return parseInt(i); }

float          = DIGIT* SPOT DIGIT+   WS  { return text().trim(); }

integer        = d:DIGIT+             WS  { return text().trim(); }

num_var        = list_itm
               / scalar_num

list_itm       = i:ID OPEN_BRACKET index:expr CLOSE_BRACKET { return { construct: "list_itm", name: "list item", child_objs: {id: i, "index": index}, children: [i, index]}; }

scalar_num     = i:ID


// Boolean expressions:
bool_expr      = bool_lit {return { name: text().trim()}; }
               / relational_expr

bool_lit       = TRUE 
               / FALSE

relational_expr= l:expr op:rel_op r:expr

rel_op         = EQUALS / GREATER_EQUAL / GREATER / LESS_EQUAL / LESS

// List of reserved words.  
keywords       = IF / TRUE / FALSE / THEN / END / PROMPT / GOTO / REPEAT / WHILE

typename       = TEXT / INT / REAL / LIST
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * LEXICAL PART                                            *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
// List of reserved words.  
keywords       = IF / TRUE / FALSE / THEN / END / PROMPT / GOTO / REPEAT / WHILE / LET / typename

typename       = tn:(TEXT / INT / REAL / LIST) { return { name: tn }; }
// Identifier for variables, labels, etc. FolloWS C++ rules.
ID             = ! keywords i:([_a-zA-Z][_a-zA-Z0-9]*) WS { return{ construct: "id", name: text().trim()}; }

DIGIT          = [0-9]

// Punctuation:
COLON          = operator:':'  WS  { return operator; }
CLOSE_BRACKET  = operator:']'  WS  { return operator; }
DBL_QUOTE      = operator:'"'  WS  { return operator; }
OPEN_BRACKET   = operator:'['  WS  { return operator; }
SPOT "decimal" = operator:'.'  WS  { return operator; }

// Arithmetic operators:
ASSIGN_OP      = operator:'='  WS  { return operator; }
CLOSE_PAREN    = operator:')'  WS  { return operator; }
DIVIDE         = operator:'/'  WS  { return operator; }
MINUS          = operator:'-'  WS  { return operator; }
OPEN_PAREN     = operator:'('  WS  { return operator; }
PLUS           = operator:'+'  WS  { return operator; }
TIMES          = operator:'*'  WS  { return operator; }

// Comparison operators:
EQUALS         = '='           WS  { return text().trim(); }
GREATER_EQUAL  = '>='          WS  { return text().trim(); }
GREATER        = '>'           WS  { return text().trim(); }
LESS_EQUAL     = '<='          WS  { return text().trim(); }
LESS           = '<'           WS  { return text().trim(); }

// Keywords
END            = 'end'         WS  { return text().trim(); }
FALSE          = 'false'       WS  { return text().trim(); }
GOTO           = 'goto'        WS  { return text().trim(); }
IF             = 'if'          WS  { return text().trim(); }
LET            = 'let'         WS  { return text().trim(); }
PRINT          = 'print'       WS  { return text().trim(); }
PROMPT         = 'prompt'      WS  { return text().trim(); }
REPEAT         = 'repeat'      WS  { return text().trim(); }
THEN           = 'then'        WS  { return text().trim(); }
TRUE           = 'true'        WS  { return text().trim(); }
WHILE          = 'while'       WS  { return text().trim(); }

// Typenames
INT            = 'int'         WS  { return text().trim(); }
REAL           = 'real'        WS  { return text().trim(); }
TEXT           = 'text'        WS  { return text().trim(); }
LIST           = 'list'        WS  { return text().trim(); }

// Whitespace (space, tab, newline)*
WS             = [ \t]*
WSNL             = [ \t\n]*