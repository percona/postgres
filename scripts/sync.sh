#!/bin/bash
# Rebase PSP_REL_<major>_STABLE onto upstream, open release branch + tag for new tag
set -euo pipefail

major=${1:?usage: sync.sh <major>}
repo=${REPO:-https://github.com/percona/postgres.git}
push_url=${PUSH_URL:-$repo}
psp=PSP_REL_${major}_STABLE
here=$(cd "$(dirname "$0")" && pwd)
summary=${GITHUB_STEP_SUMMARY:-/dev/null}

cd "$(mktemp -d)"
git init -q
git config user.name "PSP upstream sync"
git config user.email "psp-sync@users.noreply.github.com"
git config merge.keep-upstream.driver 'echo "- kept upstream %P, regenerating" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}" >&2'
git config merge.copyright.driver "$here/merge-copyright %A %B"
cat > .git/info/attributes <<ATTR
configure merge=keep-upstream
src/include/pg_config.h.in merge=keep-upstream
COPYRIGHT merge=copyright
ATTR

git fetch -q --no-tags "$repo" \
	"+refs/heads/$psp:refs/remotes/percona/$psp" \
	"+refs/heads/release-$major.*:refs/remotes/percona/release-$major.*" \
	"+refs/tags/PSP-$major.*:refs/tags/PSP-$major.*"
git fetch -q --no-tags https://github.com/postgres/postgres.git \
	"+refs/heads/REL_${major}_STABLE:refs/remotes/upstream/REL_${major}_STABLE" \
	"+refs/tags/REL_${major}_*:refs/tags/REL_${major}_*"

old=$(git rev-parse "percona/$psp")
upstream=$(git rev-parse "upstream/REL_${major}_STABLE")
base=$(git merge-base "$old" "$upstream")

regen='autoconf && autoheader && rm -rf autom4te.cache src/include/pg_config.h.in~ && { git diff --quiet || git commit -qa --amend --no-edit; }'

# replay <branch> <onto>: our patches onto <onto>
replay() {
	git checkout -q -B "$1" "$old"
	if ! git rebase -q --onto "$2" "$base" --exec "$regen" >&2; then
		git status --short | grep -E '^(UU|AA|DU|UD)' >&2 || true
		echo "- **replay onto $(git describe --tags "$2") failed**" >> "$summary"
		exit 1
	fi
	echo "- $1: $(git rev-list --count "$2..$1") patches on $(git describe --tags "$2")" >> "$summary"
}

exists() { git rev-parse -q --verify "$1" >/dev/null; }

verify() {
	git worktree add -q --detach ../tree "$1"
	(cd ../tree &&
		meson setup build --auto-features=disabled -Dcassert=true &&
		ninja -C build &&
		meson test -C build --print-errorlogs --suite setup --suite regress)
	git worktree remove --force ../tree
}

echo "### $psp" >> "$summary"
leases=()
refs=()
pushes=()

if [ "$base" != "$upstream" ]; then
	replay "$psp" "$upstream"
	leases+=("--force-with-lease=refs/heads/$psp:$old")
	refs+=("$psp")
	pushes+=("refs/heads/$psp")
fi

# newest upstream minor release (e.g. REL_17_6), empty before first GA
latest_tag=$(git tag -l "REL_${major}_*" | grep -E "^REL_${major}_[0-9]+$" | sort -V | tail -1) || true
minor=${latest_tag##*_}
rel=release-$major.$minor
if [ -n "$latest_tag" ] && ! exists "percona/$rel" && ! exists "percona/$rel.1"; then
	replay "$rel.1" "$latest_tag"
	leases+=("--force-with-lease=refs/heads/$rel.1:")
	refs+=("$rel.1")
	pushes+=("refs/heads/$rel.1")
	ptag=PSP-$major.$minor.1
	if ! exists "refs/tags/$ptag"; then
		git tag "$ptag" "$rel.1"
		leases+=("--force-with-lease=refs/tags/$ptag:")
		pushes+=("refs/tags/$ptag")
		echo "- tag $ptag" >> "$summary"
	fi
fi

if [ ${#refs[@]} = 0 ]; then
	echo "nothing to do" | tee -a "$summary"
	exit 0
fi

for r in "${refs[@]}"; do
	verify "$r"
done

[ -n "${NO_PUSH:-}" ] && { echo "NO_PUSH: ${pushes[*]}"; exit 0; }
git push --atomic "${leases[@]}" "$push_url" "${pushes[@]}"
