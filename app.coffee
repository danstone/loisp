pegjs = require('pegjs')
fs = require('fs')
_ = require('underscore')

console.log('reading grammar')
grammar = fs.readFileSync('grammar', 'utf8')
console.log('grammar read')
console.log('generating parser')
parser = pegjs.buildParser(grammar)

isSymbol = ([type, _]) -> type == 'symbol'
isNumber = ([type, _]) -> type == 'number'

compileNumber = ([type, val]) -> val
compileSymbol = (symbol) ->
  js = symbol.replace('?', '_QUOT_')
   .replace('-', '_DASH_')
   .replace('>', '_GT_')
   .replace('<', '_LT_')
   .replace('=', '_EQ_')
   .replace('!', '_BANG_')
   .replace('+', '_PLUS_')
   .replace('/', '_SLASH_')
   .replace('*', '_STAR_')
  js

compileString = (string) -> '"' + string + '"'

compileChar = (char) -> '\'' + char + '\''

compileNil = () -> 'nil'

compileVec = (elements) ->
  '[' + _.map(elements, compileExpression).join(', ') + ']'

compileLiteral = ([type, literal]) ->
  switch type
    when 'vec' then compileVec(literal)
    when 'number' then compileNumber(literal)
    when 'symbol' then compileSymbol(literal)
    when 'string' then compileString(literal)
    when 'char' then compileChar(literal)
    when 'nil' then compileNil()
    else throw Error("unrecognized literal")

numericBinOp = (op) ->
  symbol: op
  compile: (args) ->
    if _.some(args, (x) -> !(isSymbol(x) || isNumber(x))) then throw Error('##ERROR '+ op + ' only takes numeric, or symbol args')
    else
      switch args.length
        when 0 then '0'
        when 1 then compileLiteral(args[0])
        else '(' + _.map(args, compileLiteral).join(' ' + op + ' ') + ')'

primops =
  '+': numericBinOp('+')
  '-': numericBinOp('-')
  '/': numericBinOp('/')
  '*': numericBinOp('*')
  'def':
    symbol: 'def'
    compile: (args) ->
      if(!isSymbol(args[0])) then throw Error("def cannot be called without a symbol name")
      [unk, name] = args[0]
      #docs?
      expr = args[1]
      'var ' + compileSymbol(name) + ' = ' + compileExpression(expr) + ';'
  'fn':
    symbol: 'fn'
    compile: (args) ->
      [x, fargs] = args[0]
      console.log(fargs)
      jsargs = _.map(fargs, compileLiteral)
      rest = args[1..]
      body = _.map(rest, compileExpression)
      lastn = body.length - 1
      'new boot.Fn(function (' + jsargs.join(', ') + ') {' + body[0...lastn].join(';\n') + 'return ' + body[lastn] + ';}'  + ')'


isPrimOp = ([type, literal]) ->
  switch type
    when 'symbol' then _.has(primops, literal)
    else false

compileApplication = (appl) ->
  op = appl.op
  [optype, lit] = op
  args = appl.args
  if isPrimOp(op) then primops[lit].compile(args)
  else
    switch optype
      when 'symbol' then compileSymbol(lit) + '.call(' + _.map(args, compileExpression).join(',') + ')'
      when 'application' then compileApplication(list)
      else 'cannot compile... yet'

compileExpression = ([type, expr]) ->
  switch type
    when "application" then compileApplication(expr)
    else compileLiteral([type, expr])

compileApp = (exprs) ->_.map(exprs, compileExpression).join('\n')

prog =
  '(def square (fn [x] (* x x)))
   (square 5)'

test = ->
 parsed = parser.parse(prog)
 compileApp(parsed)

compiled = test()

console.log(compiled)
console.log('running!')
boot = require('./boot.js')

console.log(eval(compiled))