#!/bin/bash

#   Copyright The containerd Authors.

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# Same as refresh-docs.sh, except:
#   - it does NOT touch the submodules (no fetch of upstream), it only copies
#     from whatever is already checked out;
#   - it does not need rsync, so it also runs on Git Bash / MSYS2 on Windows.
#
# This is the script used by the Chinese translation fork: docs are materialized
# ONCE into content/docs/, translated in place, and then committed. The regular
# build must not re-run it, or translations would be wiped.
#
# Usage: ./tools/materialize-docs.sh [VERSION ...]
#        with no argument, every submodule is materialized.

set -euo pipefail

ONLY=("$@")

want() {
    [ ${#ONLY[@]} -eq 0 ] && return 0
    for v in "${ONLY[@]}"; do [ "$v" = "$1" ] && return 0; done
    return 1
}

git config --file .gitmodules --get-regexp path | awk '{ print $2 }' | \
while read -r SUBMODULE ; do
    X_VER="${SUBMODULE#containerd-}"
    want "$X_VER" || continue
    [ -d "$SUBMODULE/docs" ] || { echo "skip $X_VER: submodule not checked out"; continue; }

    echo "==> materializing $X_VER"
    rm -rf "content/docs/$X_VER"
    mkdir -p "content/docs/$X_VER"
    cp -a "$SUBMODULE/docs/." "content/docs/$X_VER/"
    find "content/docs/$X_VER/historical" -name "*.md" -delete 2>/dev/null || true

    # create titled _index.md files in all subdirs so that hugo sees them as
    # "sections" -- required for nested-menu-partial to behave correctly
    find "content/docs/$X_VER" -type d ! -name "historical" ! -path "*/historical/*" \
        -execdir bash -c 'name=$0;printf "%s\nnav_title: ${name##*/}\n%s\n" "---" "---" > "$name/_index.md";' '{}' \;

    # copy README into $X_VER/_index.md with a title added
    printf '%s\nnav_title: README\n%s\n%s\n%s\n' "---" "---" \
        "$(sed -e 's|](docs/|](|g' -e 's|](\./docs/|](|g' "$SUBMODULE/README.md")" \
        > "content/docs/$X_VER/_index.md"

    # copy images to static/ since they can't be served from content/
    rm -rf "static/docs/$X_VER"
    find "content/docs/$X_VER" -type f -exec file --mime-type {} \+ \
        | awk -F: '{if ($2 ~ /image\//) print $1}' \
        | while read -r IMG ; do
            DEST="static/${IMG#content/}"
            mkdir -p "$(dirname "$DEST")"
            cp -a "$IMG" "$DEST"
        done
done
