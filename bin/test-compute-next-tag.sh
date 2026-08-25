#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# Starts a scenario with a repository at Autobrr v1.84.0 which has already seen
# two releases of it (v1.84.0-0 and v1.84.0-1), plus `v1-0` and `v1-1` tags of
# the kind the commit-message era could produce when Renovate wrote "Docker tag
# to v1" in a subject. Those must not be counted as releases of anything.
#
# The defaults file deliberately carries the traps this role's real one has:
# Renovate's annotation, a commented-out example of the version variable, and an
# image tag derived from it. Neither of the latter two may be picked up as the
# version, and the annotation must keep sitting on the line that is.
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/meta" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	cat > defaults/main.yml <<-'YAML'
		# autobrr_version: v9.9.9
		# renovate: datasource=docker depName=ghcr.io/autobrr/autobrr versioning=semver
		autobrr_version: v1.84.0
		autobrr_container_image: "{{ autobrr_container_image_registry_prefix }}autobrr/autobrr:{{ autobrr_container_image_tag }}"
		autobrr_container_image_tag: "{{ autobrr_version }}"
	YAML
	printf 'placeholder\n' > meta/main.yml
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local tag
	for tag in v1-0 v1-1 v1.84.0-0 v1.84.0-1; do
		git tag "$tag"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version="sed -i 's|^autobrr_version: v1.84.0|autobrr_version: v1.85.0|' defaults/main.yml"
revert_version="sed -i 's|^autobrr_version: v1.85.0|autobrr_version: v1.84.0|' defaults/main.yml"
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_meta="printf 'a line\n' >> meta/main.yml"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v1.85.0-0 "$(merge "$bump_version")"
expect 'task edit'    v1.85.0-1 "$(merge "$edit_task")"
expect 'template'     v1.85.0-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v1.84.0-2 "$(merge "$edit_task")"
expect 'version bump' v1.85.0-0 "$(merge "$bump_version")"

# Autobrr's version carries its own `v`, and so do the tags. Reading one and
# writing the other must not double it, which is what a `v1.85.0-0` rather than
# a `vv1.85.0-0` above and here says.
scenario 'The leading v that the version value already carries'
expect 'version bump' v1.85.0-0 "$(merge "$bump_version")"

# `v1-0` and `v1-1` exist in every scenario. If the version were ever read as a
# bare major - exactly the mistake a commit subject of "Docker tag to v1" led
# to - the counter would continue from those instead of starting afresh.
scenario 'The floating-major tags the commit-message era could leave behind'
expect 'a task' v1.84.0-2 "$(merge "$edit_task")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'meta'     v1.84.0-2  "$(merge "$edit_meta")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v1.84.0-$release_number"
done
expect 'a task' v1.84.0-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v1.84.0-1 already published, so there is
# nothing new to release.
expect 'a revert' ''         "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v1.84.0-2 "$(merge "$revert_version && $edit_task")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
