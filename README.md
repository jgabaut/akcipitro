# akcipitro

Lex "scopes", "variables", "values" from a stego file.
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
