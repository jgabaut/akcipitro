# akcipitro

Lex "scopes", "variables", "values" from a stego file.

Used by [amboso](https://github.com/jgabaut/amboso) to parse its stego files.

The format is a restricted `TOML`.

Currently supported values:

- Plain
- Arrays (not nested directly)
- Structs (not nested)
- Arrays of structs (with above limitations)

```toml
foo = "abc"
bar = 123
baz = 10.5
[ my_scope ]
bog = [ "foo", "bar" ]
bor = [ 123, 124 ]
boz = [ 10.5, 1.5 ]
car = { foo = "123", bar = 124, baz = [ "foo", "bar" ], bog = [ 123, 124 ] }
coz = [ { foo = 123, bar = "abc" }, { foo = [ 123, 124 ] } ]
```

Output:

```console
Scope:
Variable: _foo, Value: abc
Variable: _baz, Value: 10.5
Variable: _bar, Value: 123
------------------------
Scope: my_scope
Array: my_scope_bor, Name: bor
Arrvalue: my_scope_bor[0], Value: 123
Arrvalue: my_scope_bor[1], Value:  124
Array: my_scope_bog, Name: bog
Arrvalue: my_scope_bog[0], Value: foo
Arrvalue: my_scope_bog[1], Value: bar
Array: my_scope_boz, Name: boz
Arrvalue: my_scope_boz[0], Value: 10.5
Arrvalue: my_scope_boz[1], Value:  1.5
Struct: my_scope_car, Name: car
Structvalue: my_scope_car_bar, Value: 124
Structvalue: my_scope_car_foo, Value: 123
In-Struct Array: my_scope_car_bog, Name: bog
In-Struct Array: my_scope_car_baz, Name: baz
In-Struct Arrvalue: my_scope_car_baz[0], Value: foo
In-Struct Arrvalue: my_scope_car_baz[1], Value: bar
In-Struct Arrvalue: my_scope_car_bog[0], Value:  123
In-Struct Arrvalue: my_scope_car_bog[1], Value:  124
In-Arr Struct: my_scope_coz_0, Name: coz
In-Arr Struct: my_scope_coz_1, Name: coz
In-Arr Structvalue: my_scope_coz_1[foo_0], Value:  123
In-Arr Structvalue: my_scope_coz_0[bar], Value: abc
In-Arr Structvalue: my_scope_coz_1[foo_1], Value:  124
In-Arr Structvalue: my_scope_coz_0[foo], Value: 123
In-Arr Struct Array: my_scope_coz_1_foo, Name: foo, Len: 2
------------------------
```

For each error detected in the file, prints a notice to stderr.
If any error is detected, it returns before printing to stdout.
Otherwise, prints the parsed tokens to stdout, using this format:

```console
Variable: _dog, Value: bar
------------------------
Scope: hi
Variable: hi_foo, Value: fib
Variable: hi_man, Value: bar
------------------------
```

```sh
############################################################################
#                          #                                               #
#   Format notes           #            Actual Output                      #
#                          #                                               #
############################################################################
#   main scope, named ""   #Variable: _dog, Value: bar                     #
#                          #------------------------                       #
#   other scope            #Scope: hi                                      #
#                          #Variable: hi_foo, Value: fib                   #
#                          #Variable: hi_man, Value: bar                   #
#                          #------------------------                       #
############################################################################
```
