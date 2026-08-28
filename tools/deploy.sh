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

# Ships public/ to a static file host over ssh.
#
#   ./tools/deploy.sh [SSH_HOST] [REMOTE_PATH]
#
# rsync is not available on Git Bash, so the payload is streamed as a tarball
# and unpacked remotely into a staging directory, which then atomically replaces
# the live one. That way a half-finished upload is never served.

set -euo pipefail

HOST="${1:-mycaddy}"
DEST="${2:-/srv/docs/containerd.io}"

[ -d public ] && [ -f public/index.html ] || {
    echo "public/ is missing or empty -- run 'make production-build' first" >&2
    exit 1
}

STAGING="${DEST}.incoming"
BACKUP="${DEST}.previous"

echo "==> uploading $(find public -type f | wc -l) files to ${HOST}:${DEST}"

tar -czf - -C public . | ssh "$HOST" "
    set -eu
    rm -rf '${STAGING}'
    mkdir -p '${STAGING}'
    # --no-same-owner: the tarball carries the Windows-side uid/gid, which the
    # remote host cannot (and should not) reproduce.
    tar --no-same-owner --no-same-permissions -xzf - -C '${STAGING}'
    chmod -R a+rX '${STAGING}'
    rm -rf '${BACKUP}'
    if [ -d '${DEST}' ]; then mv '${DEST}' '${BACKUP}'; fi
    mv '${STAGING}' '${DEST}'
    echo \"deployed \$(find '${DEST}' -type f | wc -l) files to ${DEST}\"
"

echo "==> done: https://docs.foyoux.dpdns.org:44443/containerd.io/"
echo "    previous release kept at ${HOST}:${BACKUP}"
