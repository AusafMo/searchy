#!/bin/bash

fix_dylib() {
    local dylib=$1
    if [ -f "$dylib" ]; then
        echo "Fixing $dylib"
        install_name_tool -change "@rpath/libSystem.B.dylib" "/usr/lib/libSystem.B.dylib" "$dylib"
        install_name_tool -id "@rpath/$(basename $dylib)" "$dylib"
        chmod 755 "$dylib"
    fi
}

# Find and fix all dylib files in the python environment
find Resources/python_env -name "*.dylib" -type f | while read dylib; do
    echo "Fixing $dylib"
    fix_dylib "$dylib"
done

# Fix specific scipy dylib
fix_dylib "Resources/python_env/lib/python3.12/site-packages/scipy/special/libsf_error_state.dylib"