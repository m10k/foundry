#!/bin/bash

# buildbot.sh - Foundry Debian package build bot
# Copyright (C) 2021-2023 Matthias Kruk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

store_packages() {
	local context="$1"
	local builddir="$2"

	local package

	while read -r package; do
		if ! foundry_context_add_file "$context" "build" "$package"; then
			log_error "Could not store artifact $package in $context"
			return 1
		fi
	done < <(find "$builddir" -type f -name "*.deb")

	return 0
}

increase_version() {
	local verrel="$1"

	local version
	local unixtime

	version="${verrel%-*}"

	if ! unixtime=$(date +"%s"); then
		return 1
	fi

	echo "$version-$unixtime"
	return 0
}

make_changelog_entry() {
	local package="$1"
	local version="$2"
	local branch="$3"
	local ref="$4"

	local datetime

	if ! datetime=$(date -R); then
		return 1
	fi

	cat <<EOF
$package ($version) unstable; urgency=medium

  * Automatic build from $branch branch [$ref]

 -- Build Bot <buildbot@m10k.eu>  $datetime
EOF

    return 0
}

prepend_changelog() {
	local changelog="$1"
	local branch="$2"
	local ref="$3"

	local package
	local prev_version
	local next_version
	local prev_changelog
	local updated_changelog

	if ! prev_changelog=$(< "$changelog"); then
		log_error "Could not read changelog"

	elif ! package=$(grep -m 1 -oP '^\K[^ ]+' <<< "$prev_changelog"); then
		log_error "Could not parse package name from changelog"

	elif ! prev_version=$(grep -m 1 -oP '^[^ ]+ \(\K[^\)]+' <<< "$prev_changelog"); then
		log_error "Could not parse previous version from changelog"

	elif ! next_version=$(increase_version "$prev_version"); then
		log_error "Could not increase version"

	elif ! updated_changelog=$(make_changelog_entry "$package"      \
	                                                "$next_version" \
	                                                "$branch"       \
	                                                "$ref"); then
		log_error "Could not make changlog entry"

	elif ! printf '%s\n\n\n%s\n' "$updated_changelog" \
	                             "$prev_changelog" > "$changelog"; then
		log_error "Could not write to changelog"

	else
		return 0
	fi

	return 1
}

prepare_buildroot() {
	local repository
	local keyring
	local args

	if [ -f /var/cache/pbuilder/base.tgz ]; then
		return 0
	fi

	args=(
		--distribution    "stable"
		--mirror          "http://ftp.debian.org/debian"
		--debootstrapopts "--keyring=/usr/share/keyrings/debian-archive-keyring.gpg"
		# Necessary when building debian buildroots on devuan
		--debootstrapopts "--exclude=devuan-keyring,devuan-baseconf"
	)

	for repository in "${extra_repositories[@]}"; do
		# We need to install apt-transport-https and ca-certificates if the repository
		# uses https, but installing them with --extrapackages doesn't seem to work. I
		# will add support for https repositories once I find a workaround.
		args+=(
			--othermirror "deb $repository"
		)
	done

	for keyring in "${extra_keyrings[@]}"; do
		args+=(
			--keyring "$keyring"
		)
	done

	if ! sudo pbuilder create "${args[@]}"; then
		return 1
	fi

	return 0
}

build_deb_in_builddir() {
	local builddir="$1"

	local -i no_packages
	local dsc

	if ! prepare_buildroot; then
		return 1
	fi

	no_packages=1

	if ! ( cd "$builddir" && dpkg-source --build "sources"); then
		log_error "Could not build source package"
		return 1
	fi

	while read -r dsc; do
		log_info "Building $dsc"

		if ! sudo pbuilder build --buildresult "$builddir" "$dsc"; then
			log_error "Build of $dsc failed"
			return 1
		fi

		no_packages=0
	done < <(find "$builddir" -type f -name "*.dsc")

	return "$no_packages"
}

build() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local ref="$4"
	local builddir="$5"
	local -i allow_unsigned="$6"

	local output
	local err
	local -i signature_is_valid

	err=0
	signature_is_valid=0

	if ! output=$(git clone "$repository" "$builddir/sources" 2>&1) ||
	   ! output+=$(cd "$builddir/sources" 2>&1 && git checkout "$branch" 2>&1); then
		err=1
	fi

	if output+=$(cd "$builddir/sources" 2>&1 && git verify-commit "$ref" 2>&1); then
	        signature_is_valid=1
	fi

	if ! foundry_context_log "$context" "build" <<< "$output"; then
		log_error "Could not log to $context"
		return 1
	fi

	if (( err != 0 )); then
		return 1
	fi

	if (( signature_is_valid == 0 )) && (( allow_unsigned == 0 )); then
		foundry_context_log "$context" "build" "Rejecting source without valid signature"
		return 1
	fi

	if array_contains "$branch" "${autobump_branches[@]}"; then
		if ! prepend_changelog "$builddir/sources/debian/changelog" \
		                       "$branch"                            \
		                       "$ref"; then
			log_error "Could not add entry to $builddir/sources/debian/changelog"
			return 1
		fi
	fi

	if ! output=$(build_deb_in_builddir "$builddir"); then
		err=1
	fi

	if ! foundry_context_log "$context" "build" <<< "$output"; then
		log_error "Could not log to $context"
		return 1
	fi

	if (( err != 0 )); then
		return 1
	fi

	if ! store_packages "$context" "$builddir"; then
		log_error "Could not store packages for $context"
		return 1
	fi

	return 0
}

send_build_notification() {
	local endpoint="$1"
	local topic="$2"
	local context="$3"
	local repository="$4"
	local branch="$5"
	local ref="$6"
	local result="$7"

	local buildmsg
	local artifacts

	artifacts=()

	if ! buildmsg=$(foundry_msg_build_new "$context"    \
					      "$repository" \
					      "$branch"     \
					      "$ref"        \
					      "$result"     \
					      artifacts); then
		log_error "Could not make build message"
		return 1
	fi

	log_info "Sending build message to $topic"
	if ! ipc_endpoint_publish "$endpoint" "$topic" "$buildmsg"; then
		log_error "Could not publish message on $endpoint to $topic"
		return 1
	fi

	return 0
}

handle_commit_message() {
	local endpoint="$1"
	local publish_to="$2"
	local commit="$3"
	local -i allow_unsigned="$4"

	local repository
	local branch
	local ref
	local context_name
	local context
	local builddir
	local -i result
	local -i err

	result=0
	err=0

	if ! branch=$(foundry_msg_commit_get_branch "$commit"); then
		log_warn "No branch in commit message"
		return 1
	fi

	if ! array_contains "$branch" "${build_branches[@]}" &&
	   ! array_contains "*"       "${build_branches[@]}"; then
		log_warn "Branch $branch not in list of to-build branches"
		return 0
	fi

	if ! repository=$(foundry_msg_commit_get_repository "$commit"); then
		log_warn "No repository in commit message"
		return 1
	fi

	if ! ref=$(foundry_msg_commit_get_ref "$commit"); then
		log_warn "No ref in commit message"
		return 1
	fi

	context_name="${repository##*/}"

	if ! context=$(foundry_context_new "$context_name"); then
		log_error "Could not create a context for $context_name"
		return 1
	fi

	inst_set_status "Building $context"

	if ! builddir=$(mktemp -d); then
		log_error "Could not make temporary build directory"
		return 1
	fi

	log_info "Building $context in $builddir"
	if ! build "$context" "$repository" "$branch" "$ref" "$builddir" "$allow_unsigned"; then
		result=1
	fi

	log_info "Finished build of $context with status $result"

	if ! send_build_notification "$endpoint" "$publish_to" "$context" \
	                             "$repository" "$branch" "$ref" "$result"; then
		err=1
	fi

	if ! rm -rf "$builddir"; then
		log_warn "Could not remove temporary build directory $builddir"
	fi

	return "$err"
}

dispatch_tasks() {
	local endpoint_name="$1"
	local watch="$2"
	local publish_to="$3"
	local -i allow_unsigned="$4"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open endpoint $endpoint_name"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "$watch"; then
		log_error "Could not subscribe to $watch"
		return 1
	fi

	while inst_running; do
		local msg
		local data
		local msgtype

		inst_set_status "Awaiting commit messages"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping malformed message"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$data") ||
		   [[ "$msgtype" != "commit" ]]; then
			log_warn "Dropping message with unexpected type"
			continue
		fi

		inst_set_status "Handling commit message"

		handle_commit_message "$endpoint" "$publish_to" "$data" "$allow_unsigned"
	done

	return 0
}


main() {
	local endpoint
	local watch
	local publish_to
	local proto
	local -i allow_unsigned
	declare -ag build_branches
        declare -ag autobump_branches
	declare -ag extra_repositories
	declare -ag extra_keyrings

	opt_add_arg "e" "endpoint"       "v" "pub/buildbot"      "The IPC endpoint to listen on"
	opt_add_arg "w" "watch"          "v" "commits"           "The topic to watch for commit messages"
	opt_add_arg "p" "publish-to"     "v" "builds"            "The topic to publish builds under"
	opt_add_arg "a" "autobump"       "av" autobump_branches  "Automatically bump revision on branch"
	opt_add_arg "b" "build-branch"   "av" build_branches     "Branch to build packages from"
	opt_add_arg "P" "proto"          "v" "uipc"              "The IPC flavor to use"                   \
	            '^u?ipc$'
	opt_add_arg "U" "allow-unsigned" ""  0                   "Don't refuse to build unsigned code"
	opt_add_arg "r" "repository"     "av" extra_repositories "Additional repository to use for builds" \
	            '^([^ ]+) ([^ ]+)( [^ ]+)+$'
	opt_add_arg "k" "keyring"        "av" extra_keyrings     "Additional GPG keyrings to use"

	if ! opt_parse "$@"; then
		return 1
	fi

	if (( ${#build_branches[@]} == 0 )); then
		# build all branches by default
		build_branches+=("*")
	fi

	endpoint=$(opt_get "endpoint")
	watch=$(opt_get "watch")
	publish_to=$(opt_get "publish-to")
	proto=$(opt_get "proto")
	allow_unsigned=$(opt_get "allow-unsigned")

	if ! include "$proto"; then
		return 1
	fi

	if ! inst_start dispatch_tasks "$endpoint" "$watch" "$publish_to" "$allow_unsigned"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
