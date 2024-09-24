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
    } else if ($0 ~ /^[^-A-Z_\[\]\$\\\/{}]+ *= *{[^}A-Z\\\$#\]\[]+ *}$/) {
        # Check if line has a curly bracket rightval
        # Extract variable
        variable = gensub(/^ *"?([^{="]+)"? *=.*$/, "\\1", "g", $0)
        value = gensub(/^.*= *{ *([^}A-Z\\\$]+) *}$/, "\\1", "g", $0)
        # Trim trailing whitespaces from variable and value
        gsub(/[ \t]+$/, "", variable)
        gsub(/[ \t]+$/, "", value)
        if (current_scope == "main") {
            variable = "main_" variable
        }
        values[current_scope "_" variable]=value
        if (!(current_scope in scopes)) {
            scopes[current_scope]++
        }
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
            print "------------------------"
        }
    }
}
