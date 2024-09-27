#!/usr/bin/gawk -f
#
# Take TOML as input and output it with inline-only values.
# Return 1 on errors.

BEGIN {
    buffer = "";
    open_brackets = 0;
    open_curly = 0;
}

{
    # Add the current line to the buffer
    buffer = buffer $0;

    # Count the opening and closing brackets/braces in the current line
    num_open_brackets = gsub(/\[/, "[", $0);
    num_close_brackets = gsub(/\]/, "]", $0);
    num_open_curly = gsub(/\{/, "{", $0);
    num_close_curly = gsub(/\}/, "}", $0);

    # Update the counters
    open_brackets += num_open_brackets - num_close_brackets;
    open_curly += num_open_curly - num_close_curly;

    # Check for negative counts (more closing than opening brackets/braces)
    if (open_brackets < 0 || open_curly < 0) {
        print "Error: Unmatched closing bracket or brace detected at line " NR
        exit 1
    }

    # Check if all brackets and curly braces are closed
    if (open_brackets == 0 && open_curly == 0) {
        # We've reached the end of a multi-line structure, print the complete declaration
        print buffer;
        # Reset buffer for the next structure
        buffer = "";
    } else {
        # Continue accumulating lines (add space if needed)
        buffer = buffer " ";
    }
}

END {
    # At the end of input, check for unmatched opening brackets/braces
    if (open_brackets > 0 || open_curly > 0) {
        print "Error: Unmatched opening bracket or brace detected at end of file"
        exit 1
    }
}

