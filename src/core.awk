#!/usr/bin/awk -f
{
    # Remove leading and trailing whitespaces
    gsub(/^[ \t]+|[ \t]+$/, "")

    # Remove trailing comments outside quotes
    gsub(/#[^\n"]*$/, "")

    # Skip empty lines
    if ($0 == "") {
        next
    }

    if ($0 ~ /^\s*\[[^-A-Z\[\]\\\/\$]+\]\s*$/) {
        # Extract and set the current scope
        if (match($0, /^\s*\[\s*([^-A-Z\[\]]+)\s*\]\s*$/, a)) {
            current_scope=gensub(/\s*$/, "", "g", a[1])
            scopes[current_scope]++
        } else {
            print "[LINT]    Invalid header:    " $0 "" > "/dev/stderr"
            error_flag=1
        }
    } else if ($0 ~ /^"?[^"=\[\]_\$\\\/{}]+"? *= *"[^=\[\]\${}]+"$/) {
        # Check if the line is a valid variable assignment

        split($0, parts, "=")
        variable=gensub(/^ *"?([^"]+)"? *$/, "\\1", "g", parts[1])
        value=gensub(/^ *"?([^"]*)"? *$/, "\\1", "g", parts[2])

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
    } else if ($0 ~ /^[^-A-Z_\[\]\$\\\/{}]+ *= *{ *(([^-A-Z_\[\]\$\\\/{}]+) *= *\[ *(" *[^\]A-Z\\\$#\]\[]+ *" *)(, *" *[^\]A-Z\\\$#\]\[]+ *")* *,? *\] *)(, ([^-A-Z_\[\]\$\\\/{}]+) *= *\[ *(" *[^\]A-Z\\\$#\]\[]+ *" *)(, *" *[^\]A-Z\\\$#\]\[]+ *")* *,? *\] *)* *}$/) {
        # Check if line has a curly bracket array rightval
        # Extract variable
        variable = gensub(/^ *"?([^{="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *{ *([^}A-Z]+) *}$/, "\\1", "g", $0)
        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)
        if (current_scope == "main") {
            variable = "main_" variable
        }

        #struct_values[current_scope "_" variable]=value
        #struct_names[current_scope "_" variable ]=variable

        while (match(value, /^ *,? *"?([^\]A-Z\\\$#\]\["]+)"? *= *\[ *([^\]A-Z\\\$#\]\[]+) *\] */, parts)) {
            # Trim trailing whitespaces from variable and value
            gsub(/[ \t]+$/, "", parts[0])
            gsub(/[ \t]+$/, "", parts[1])
            # Trim leading whitespaces from variable and value
            gsub(/^[ \t]+/, "", parts[0])
            gsub(/^[ \t]+/, "", parts[1])
            #print "[LINT]    Parts[0]: { " parts[0] " }"
            #print "[LINT]    Parts[1]: { " parts[1] " }"
            # Extract val
            arrname = parts[1]
            arrval = gensub(/^.*= *\[ *([^\[A-Z\\\$]+) *\]$/, "\\1", "g", parts[0])

            # Trim trailing whitespaces from arrname, arrval
            gsub(/[ \t]+$/, "", arrname)
            gsub(/[ \t]+$/, "", arrval)

            #print "[LINT]    Arrname: { " arrname " }"
            #print "[LINT]    Arrval: { " arrval " }"

            arr_idx=0;
            split(arrval, arr_tokens, ",");
            for (arr_value in arr_tokens) {
                val = gensub(/^ *"([^"=,\\\]]+)" *$/, "\\1", "g", arr_tokens[arr_value])
                if (val != "") {
                    struct_array_values[current_scope "_" variable "_" arrname "[" arr_idx "]" ]=val
                    if (!(current_scope in scopes)) {
                        scopes[current_scope]++
                    }
                    arr_idx++
                }
            }
            if (arr_idx > 0) {
                struct_array_names[current_scope "_" variable "_" arrname ]=arrname
            }

            sub(/^[^\]A-Z\\\$#\]\[]+ *= *\[ *[^\]A-Z\\\$#\]\[]+ *\] *,?/,"",value)
        }

    } else if ($0 ~ /^[^-A-Z_\[\]\$\\\/{}]+ *= *{ *(" *[^}A-Z\\\$#\]\[]+ *" *= *" *[^}A-Z\\\$#\]\[]+ *" *)(, *" *[^}A-Z\\\$#\]\[]+ *" *= *" *[^}A-Z\\\$#\]\[]+ *" *)* *}$/) {
        # Check if line has a curly bracket rightval
        # Extract variable
        variable = gensub(/^ *"?([^{="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *{ *([^}A-Z]+) *}$/, "\\1", "g", $0)
        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)
        if (current_scope == "main") {
            variable = "main_" variable
        }
        split(value, struct_tokens, ",");
        for (struct_decl in struct_tokens) {
            split(struct_tokens[struct_decl], parts, "=")
            var=gensub(/^ *"?([^"]+)"? *$/, "\\1", "g", parts[1])
            val=gensub(/^ *"?([^"]*)"? *$/, "\\1", "g", parts[2])
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
        struct_names[current_scope "_" variable ]=variable
    } else if ($0 ~ /^[^-A-Z_\[\]\$\\\/{}]+ *= *\[ *(" *[^\]A-Z\\\$#\]\[]+ *" *)(, *" *[^\]A-Z\\\$#\]\[]+ *")* *,? *\]$/) {
        # Check if line has a square bracket rightval
        # Extract variable
        variable = gensub(/^ *"?([^\[="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *\[ *([^\[A-Z\\\$]+) *\]$/, "\\1", "g", $0)

        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)

        if (current_scope == "main") {
            variable = "main_" variable
        }

        arr_idx=0;
        split(value, arr_tokens, ",");
        for (arr_value in arr_tokens) {
            val = gensub(/^ *"([^"=,\\\]]+)" *$/, "\\1", "g", arr_tokens[arr_value])
            if (val != "") {
                array_values[current_scope "_" variable "[" arr_idx "]" ]=val
                if (!(current_scope in scopes)) {
                    scopes[current_scope]++
                }
                arr_idx++
            }
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
            print "------------------------"
        }
    }
}
