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

DEPLOY_HOST ?= mycaddy
DEPLOY_PATH ?= /srv/docs/containerd.io

clean:
	rm -rf public resources

# Re-imports the English docs from the submodules. This OVERWRITES the Chinese
# translations under content/docs/, so unlike upstream it is NOT a build step:
# run it by hand when picking up a new upstream release, then re-translate.
refresh-docs:
	./tools/refresh-docs.sh

# Same import, but without touching the submodules and without needing rsync,
# so it also works on Git Bash / MSYS2. Same warning as above.
materialize-docs:
	./tools/materialize-docs.sh

serve:
	hugo server \
		--buildDrafts \
		--buildFuture \
		--disableFastRender

production-build:
	hugo \
	--minify

preview-build:
	hugo \
		--baseURL $(DEPLOY_PRIME_URL) \
		--buildDrafts \
		--buildFuture

deploy: clean production-build
	./tools/deploy.sh $(DEPLOY_HOST) $(DEPLOY_PATH)

install-link-checker:
	curl https://raw.githubusercontent.com/wjdp/htmltest/master/godownloader.sh | bash

run-link-checker:
	bin/htmltest

check-links: clean production-build install-link-checker run-link-checker
