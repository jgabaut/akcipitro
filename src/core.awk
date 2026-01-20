#!/usr/bin/awk -f
function split_top_level(s, out,    i,c,buf,depth_sq,depth_cu,in_str,n) {
    n = 0
    buf = ""
    depth_sq = depth_cu = 0
    in_str = 0

    for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)

        if (c == "\"" && substr(s, i-1, 1) != "\\")
            in_str = !in_str

        if (!in_str) {
            if (c == "[") depth_sq++
            else if (c == "]") depth_sq--
            else if (c == "{") depth_cu++
            else if (c == "}") depth_cu--
        }

        if (c == "," && !in_str && depth_sq == 0 && depth_cu == 0) {
            out[++n] = buf
            buf = ""
            continue
        }

        buf = buf c
    }

    if (buf != "")
        out[++n] = buf

    return n
}

{
    # Remove leading and trailing whitespaces
    gsub(/^[ \t]+|[ \t]+$/, "")

    # Remove trailing comments outside quotes
    gsub(/#[^\n"]*$/, "")

    # Skip empty lines
    if ($0 == "") {
        next
    }


    banned = "$\"\047\\\\"
    ban_slash = "\\/"
    scope_rgx = "^[[:space:]]*\\[[^A-Z\\[\\]=" banned ban_slash "]+\\][[:space:]]*$"
    int_rgx = "[+-]?[0-9]+(_[0-9]+)*"
    float_rgx = "[+-]?([[:digit:]]+(\\.[[:digit:]]*)?|\\.[[:digit:]]+)([eE][+-]?[[:digit:]]+)?"
    year_rgx = "[0-9]{4}"
    month_rgx = "(0[1-9]|1[0-2])"
    day_rgx = "(0[1-9]|[12][0-9]|3[01])"
    date_rgx = year_rgx "-" month_rgx "-" day_rgx
    hour_rgx = "([01][0-9]|2[0-3])"
    minute_rgx = "[0-5][0-9]"
    second_rgx = "[0-5][0-9]"
    second_frac_rgx = "(\\.[0-9]+)?"
    time_rgx = hour_rgx ":" minute_rgx ":" second_rgx second_frac_rgx
    time_offset_rgx = "(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])"
    odt_rgx = date_rgx "[T ]" time_rgx time_offset_rgx
    ldt_rgx = date_rgx "[T ]" time_rgx
    ld_rgx = date_rgx
    lt_rgx = time_rgx
    datetime_rgx = "(" odt_rgx "|" ldt_rgx "|" ld_rgx "|" lt_rgx ")"
    var_lhs_rgx = "(\" *[^-}#\\]\\[=" banned ban_slash "]+ *\"|[^-}#\\]\\[=" banned ban_slash "]+)"
    var_rhs_rgx = "(\" *[^}\\]\\[" banned "]* *\"|true|false|" int_rgx "|" float_rgx "|" datetime_rgx ")"
    var_rgx = "^" var_lhs_rgx " *= *" var_rhs_rgx "$"
    arr_val_rgx = " *((\" *[^}\\]\\[," banned "]* *\" *)(, *\" *[^}\\]\\[," banned "]* *\" *)*|( *(true|false) *)(, *(true|false) *)*|( *" int_rgx " *)(, *" int_rgx " *)*|( *" float_rgx " *)(, *" float_rgx " *)*|( *" datetime_rgx " *)(, *" datetime_rgx " *)*) *,? *"
    arr_rgx = "^" var_lhs_rgx " *= *\\[" arr_val_rgx "\\]$"
    struct_val_rgx = " *(" var_lhs_rgx " *= *(" var_rhs_rgx "|\\[" arr_val_rgx "\\]) *)(, *" var_lhs_rgx " *= *(" var_rhs_rgx "|\\[" arr_val_rgx "\\]) *)* *"
    struct_rgx = "^" var_lhs_rgx " *= *\\{" struct_val_rgx "\\}$"
    arr_struct_rgx = "^" var_lhs_rgx " *= *\\[ *\\{" struct_val_rgx "\\} *(, *\\{" struct_val_rgx "\\})* *,? *\\]$"

    if ($0 ~ scope_rgx) {
        # Extract and set the current scope
        if (match($0, /^\s*\[\s*([^A-Z\[\]]+)\s*\]\s*$/, a)) {
            current_scope=gensub(/\s*$/, "", "g", a[1])
            # Replace dashes with underscores
            gsub(/[-]/, "_", current_scope)
            # Replace dots with underscores
            gsub(/[.]/, "_", current_scope)
            scopes[current_scope]++
        } else {
            print "[LINT]    Invalid header:    " $0 "" > "/dev/stderr"
            error_flag=1
        }
    } else if ($0 ~ var_rgx) {
        # Check if the line is a valid variable assignment

        variable = gensub(/^ *"?([^="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *"?([^"]*)"? *$/, "\\1", "g", $0)

        # Replace dashes with underscores
        gsub(/[-]/, "_", variable)

        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)

        # Check if left side contains disallowed characters
        if (index(variable, " ") > 0 || (index(variable, "#") > 0 && index(variable, "\"") == 0)) {
            print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " variable "" > "/dev/stderr"
            error_flag=1
            next
        }

        if (current_scope == "main") {
            variable = "main_" variable
        }
        values[current_scope "_" variable]=value
        if (!(current_scope in scopes)) {
            scopes[current_scope]++
        }
    } else if ($0 ~ struct_rgx) {
        # Check if line has a curly bracket rightval
        # Extract variable
        variable = gensub(/^ *"?([^{="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *{ *([^}]+) *}$/, "\\1", "g", $0)
        # Replace dashes with underscores
        gsub(/[-]/, "_", variable)
        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)
        # Check if left side contains disallowed characters
        if (index(variable, " ") > 0 || (index(variable, "#") > 0 && index(variable, "\"") == 0)) {
            print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " variable "" > "/dev/stderr"
            error_flag=1
            next
        }
        if (current_scope == "main") {
            variable = "main_" variable
        }
        #split(value, struct_tokens, ",");
        delete struct_tokens
        n = split_top_level(value, struct_tokens)
        for (struct_decl in struct_tokens) {
            if (match(struct_tokens[struct_decl], /^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$/, m)) {
                var = m[1]
                val = m[2]

                var=gensub(/^ *"?([^"]+)"? *$/, "\\1", "g", var)
                if(match(val, " *\\[(" arr_val_rgx ")\\] *$", m2)) {
                    arr_idx=0;
                    split(m2[1], arr_tokens, ",");
                    for (arr_value in arr_tokens) {
                        m2[1] = gensub(/^ *"([^"=,\\\]]*)" *$/, "\\1", "g", arr_tokens[arr_value])
                        struct_array_values[current_scope "_" variable "_" var "[" arr_idx "]" ]=m2[1]
                        if (!(current_scope in scopes)) {
                            scopes[current_scope]++
                        }
                        arr_idx++
                    }
                    if (arr_idx > 0) {
                        struct_array_names[current_scope "_" variable "_" var ]=var
                    }
                } else {
                    val=gensub(/^ *"?([^"]*)"? *$/, "\\1", "g", val)
                    # Trim trailing whitespaces from variable and value
                    gsub(/[ \t]+$/, "", var)
                    gsub(/[ \t]+$/, "", val)

                    # Check if left side contains disallowed characters
                    if (index(var, " ") > 0 || (index(var, "#") > 0 && index(var, "\"") == 0)) {
                        print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " var "" > "/dev/stderr"
                        error_flag=1
                        next
                    }
                    if (!(current_scope in scopes)) {
                        scopes[current_scope]++
                    }
                    struct_values[current_scope "_" variable "_" var]=val
                }
            } else {
                print "[LEX]    Failed capture of struct_decl " struct_tokens[struct_decl] "" > "/dev/stderr"
                error_flag=1
                next
            }
        }
        struct_names[current_scope "_" variable ]=variable
    } else if ($0 ~ arr_struct_rgx) {
        # Check if line has a square bracket struct rightval

        # Extract variable
        variable = gensub(/^ *"?([^\{\[="]+)"? *=.*$/, "\\1", "g", $0)
        value = $0
        sub(/^[^[]*\[/, "", value)   # remove up to first '['
        sub(/\][^]]*$/, "", value)   # remove from last ']'

        # Replace dashes with underscores
        gsub(/[-]/, "_", variable)
        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)

        # Check if left side contains disallowed characters
        if (index(variable, " ") > 0 || (index(variable, "#") > 0 && index(variable, "\"") == 0)) {
            print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " variable "" > "/dev/stderr"
            error_flag=1
            next
        }

        if (current_scope == "main") {
            variable = "main_" variable
        }

        #struct_values[current_scope "_" variable]=value
        #struct_names[current_scope "_" variable ]=variable

        curr_idx=0
        while (match(value,/^ *({ *[^{}\\\$#]+ *} *,? *)+ *$/, parts)) {
            current_decl = gensub(/^ *{ *([^{}\\\$#]+) *}.*$/, "\\1", 1, value)

            # Extract variable
            struct_variable = gensub(/^ *"?([^{="]+)"? *=.*$/, "\\1", "g", current_decl)
            struct_value = gensub(/^.*= *{ *([^}]+) *}$/, "\\1", "g", current_decl)
            # Replace dashes with underscores
            gsub(/[-]/, "_", struct_variable)
            # Trim trailing whitespaces from variable and value
            gsub(/[ \t]+$/, "", struct_variable)
            gsub(/[ \t]+$/, "", struct_value)
            # Check if left side contains disallowed characters
            if (index(struct_variable, " ") > 0 || (index(struct_variable, "#") > 0 && index(struct_variable, "\"") == 0)) {
                print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " struct_variable "" > "/dev/stderr"
                error_flag=1
                next
            }
            delete struct_tokens
            n = split_top_level(current_decl, struct_tokens)
            for (struct_decl in struct_tokens) {
                if (match(struct_tokens[struct_decl], /^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*(.*)$/, m)) {
                    var = m[1]
                    val = m[2]
                    var=gensub(/^ *"?([^}]+)"? *$/, "\\1", "g", var)
                    if(match(val, " *\\[(" arr_val_rgx ")\\] *$", m2)) {
                        arr_idx=0;
                        split(m2[1], arr_tokens, ",");
                        for (arr_value in arr_tokens) {
                            m2[1] = gensub(/^ *"([^"=,\\\]]*)" *$/, "\\1", "g", arr_tokens[arr_value])
                            arr_struct_values[current_scope "_" variable "_" curr_idx "[" var "_" arr_idx "]" ]=m2[1]
                            if (!(current_scope in scopes)) {
                                scopes[current_scope]++
                            }
                            arr_idx++
                        }
                        if (arr_idx > 0) {
                            arr_struct_array_names[current_scope "_" variable "_" curr_idx "_" var ]=var
                            arr_struct_array_lengths[current_scope "_" variable "_" curr_idx "_" var ]=arr_idx
                        }
                    } else {
                        val=gensub(/^ *"?([^"]*)"? *$/, "\\1", "g", val)
                        # Trim trailing whitespaces from variable and value
                        gsub(/[ \t]+$/, "", var)
                        gsub(/[ \t]+$/, "", val)

                        # Check if left side contains disallowed characters
                        if (index(var, " ") > 0 || (index(var, "#") > 0 && index(var, "\"") == 0)) {
                            print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " var "" > "/dev/stderr"
                            error_flag=1
                            next
                        }
                        if (!(current_scope in scopes)) {
                            scopes[current_scope]++
                        }
                        arr_struct_values[current_scope "_" variable "_" curr_idx "[" var "]"]=val
                    }
                } else {
                    print "[LEX]    Failed capture of struct_decl " struct_tokens[struct_decl] "" > "/dev/stderr"
                    error_flag=1
                    next
                }
            }
            arr_struct_names[current_scope "_" variable "_" curr_idx ]=variable

            sub(/^ *{ *[^}\\\$#]+ *} *,?/,"",value)
            curr_idx++
        }
    } else if ($0 ~ arr_rgx) {
        # Check if line has a square bracket rightval
        # Extract variable
        variable = gensub(/^ *"?([^\[="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *\[ *([^\[\\\$]+) *\]$/, "\\1", "g", $0)

        # Replace dashes with underscores
        gsub(/[-]/, "_", variable)

        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)

        # Check if left side contains disallowed characters
        if (index(variable, " ") > 0 || (index(variable, "#") > 0 && index(variable, "\"") == 0)) {
            print "[LINT]    Invalid left side (contains spaces or disallowed characters):    " variable "" > "/dev/stderr"
            error_flag=1
            next
        }

        if (current_scope == "main") {
            variable = "main_" variable
        }

        arr_idx=0;
        split(value, arr_tokens, ",");
        for (arr_value in arr_tokens) {
            val = gensub(/^ *"([^",\\\]]*)" *$/, "\\1", "g", arr_tokens[arr_value])
            array_values[current_scope "_" variable "[" arr_idx "]" ]=val
            if (!(current_scope in scopes)) {
                scopes[current_scope]++
            }
            arr_idx++
        }
        if (arr_idx > 0) {
            array_names[current_scope "_" variable ]=variable
        }
        # This would output an additional variable holding the array length.
        # Omitted for now.
        #values[current_scope "_" variable "$len"]=arr_idx
    } else {
            if ($0 ~ /^$/) {
                # This is a comment-only line and we can ignore it
                next
            } else {
                print "[LINT]    Invalid line:    " $0 "" > "/dev/stderr"
                error_flag=1
            }
    }
} END {
    if (error_flag == 1) {
            print "[LEX]    Errors while lexing." > "/dev/stderr"
    } else {
        # Print each scope and its variable-value pairs
        for (scope in scopes) {
            print "Scope: " scope
            for (var in values) {
                if (index(var, scope "_") == 1 || (scope == "main" && index(var, "main_") == 1)) {
                    print "Variable: " var ", Value: " values[var]
                }
            }
            for (arr_name in array_names) {
                if (index(arr_name, scope "_") == 1 || (scope == "main" && index(arr_name, "main_") == 1)) {
                    print "Array: " arr_name ", Name: " array_names[arr_name]
                    for (arr_value in array_values) {
                        if (index(arr_value, scope "_" array_names[arr_name]) == 1 || (scope == "main" && index(arr_value, "main_" array_names[arr_name]) == 1)) {
                            print "Arrvalue: " arr_value ", Value: " array_values[arr_value]
                        }
                    }
                }
            }
            for (struct_name in struct_names) {
                if (index(struct_name, scope "_") == 1 || (scope == "main" && index(struct_name, "main_") == 1)) {
                    print "Struct: " struct_name ", Name: " struct_names[struct_name]
                    for (struct_value in struct_values) {
                        if (index(struct_value, scope "_" struct_names[struct_name]) == 1 || (scope == "main" && index(struct_value, "main_" struct_names[struct_name]) == 1)) {
                            print "Structvalue: " struct_value ", Value: " struct_values[struct_value]
                        }
                    }
                }
            }
            for (struct_arr_name in struct_array_names) {
                if (index(struct_arr_name, scope "_") == 1 || (scope == "main" && index(struct_arr_name, "main_") == 1)) {
                    print "In-Struct Array: " struct_arr_name ", Name: " struct_array_names[struct_arr_name]
                }
            }
            for (struct_arr_value in struct_array_values) {
                if (index(struct_arr_value, scope "_") == 1 || (scope == "main" && index(struct_arr_value, "main_") == 1)) {
                    print "In-Struct Arrvalue: " struct_arr_value ", Value: " struct_array_values[struct_arr_value]
                }
            }
            for (arr_struct_name in arr_struct_names) {
                if (index(arr_struct_name, scope "_") == 1 || (scope == "main" && index(arr_struct_name, "main_") == 1)) {
                    print "In-Arr Struct: " arr_struct_name ", Name: " arr_struct_names[arr_struct_name]
                }
            }
            for (arr_struct_value in arr_struct_values) {
                if (index(arr_struct_value, scope "_") == 1 || (scope == "main" && index(arr_struct_value, "main_") == 1)) {
                    print "In-Arr Structvalue: " arr_struct_value ", Value: " arr_struct_values[arr_struct_value]
                }
            }
            for (arr_struct_arr_name in arr_struct_array_names) {
                if (index(arr_struct_arr_name, scope "_") == 1 || (scope == "main" && index(arr_struct_arr_name, "main_") == 1)) {
                    print "In-Arr Struct Array: " arr_struct_arr_name ", Name: " arr_struct_array_names[arr_struct_arr_name] ", Len: " arr_struct_array_lengths[arr_struct_arr_name]
                }
            }
            print "------------------------"
        }
    }
}
