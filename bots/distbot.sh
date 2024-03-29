#!/bin/bash

# distbot.sh - Foundry Debian repository management bot
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

make_repo_config() {
    local domain="$1"
    local codename="$2"
    local architectures="$3"
    local gpgkeyid="$4"
    local description="$5"

    echo "Origin: $domain"
    echo "Label: $domain"
    echo "Codename: $codename"
    echo "Architectures: $architectures"
    echo "Components: main"
    echo "Description: $description"
    echo "SignWith: $gpgkeyid"

    return 0
}

repo_init() {
	local repo="$1"
	local domain="$2"
	local arch="$3"
	local gpgkeyid="$4"
	local description="$5"
	local codenames=("${@:6}")

	local codename

	if ! mkdir -p "$repo/conf" "$repo/incoming" "$repo/failed" &>/dev/null; then
		log_error "Could not create directory structure in $repo"
		return 1
	fi

	for codename in "${codenames[@]}"; do
		local config

		config=$(make_repo_config "$domain" "$codename" "$arch" \
	                                  "$gpgkeyid" "$description")

		if ! printf "%s\n\n" "$config" >> "$repo/conf/distributions"; then
			return 1
		fi
	done

	return 0
}

repo_add_package() {
	local repository="$1"
	local codename="$2"
	local package="$3"

	log_info "Adding $package to $repository:$codename"

	if ! reprepro -b "$repository" includedeb \
	              "$codename" "$package"; then
		return 1
	fi

	return 0
}

verify_package() {
	local package="$1"

	local output
	local -i retval
	local -a result

	log_info "Verifying signature on $package"

	output=$(dpkg-sig --verify "$package" 2>&1)
	retval="$?"

	result["$retval"]="Invalid"
	result[0]="Valid"

	log_info "${result[$retval]} signature on $package"
	log_highlight "dpkg-sig --verify \"$package\" = $retval" <<< "$output" | log_info

	return "$retval"
}

process_new_package() {
	local context="$1"
	local package="$2"
	local repo="$3"
	local codename="$4"

	local failed
	local logoutput

	failed=true

	log_info "[#$context] New package: $package"

	if ! logoutput=$(verify_package "$package" 2>&1); then
		log_error "[#$context] Invalid signature on package $package"
	elif ! logoutput+=$(repo_add_package "$repo" "$codename" "$package" 2>&1); then
		log_error "[#$context] Could not process $package"
	else
		log_info "[#$context] $package successfully added to $repo:$codename"
		failed=false
	fi

	if "$failed"; then
		if ! log_output+=$(mv "$package" "$repo/failed/." 2>&1); then
			log_error "[#$context] Could not move $package to $repo/failed/."
		fi
	else
		if ! log_output+=$(rm "$package" 2>&1); then
			log_error "[#$context] Could not remove $package"
		fi
	fi

	if ! foundry_context_log "$context" "dist" <<< "$logoutput"; then
		log_error "Could not log to dist log of $context"
		return 1
	fi

	return 0
}

publish_result() {
	local endpoint="$1"
	local publish_to="$2"
	local repository="$3"
	local branch="$4"
	local ref="$5"
	local distribution="$6"
	local artifacts=("${@:7}")

	local message

	if ! message=$(foundry_msg_dist_new "$repository"   \
					    "$branch"       \
					    "$ref"          \
					    "$distribution" \
					    "${artifacts[@]}"); then
		log_error "Could not make dist message"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$publish_to" "$message"; then
		log_error "Could not publish message to $publish_to"
		return 1
	fi

	return 0
}

process_sign_message() {
	local repo="$1"
	local signmsg="$2"
	local endpoint="$3"
	local publish_to="$4"

	local artifacts
	local artifact
	local context
	local repository
	local branch
	local ref
	local distributed
	local codename

	distributed=()

	if ! repository=$(foundry_msg_sign_get_repository "$signmsg") ||
	   ! branch=$(foundry_msg_sign_get_branch "$signmsg")         ||
	   ! ref=$(foundry_msg_sign_get_ref "$signmsg")               ||
	   ! context=$(foundry_msg_sign_get_context "$signmsg"); then
		log_warn "Dropping malformed message"
		return 1
	fi

	codename="${codename_map[$branch]-${codename_map["*"]}}"

	readarray -t artifacts < <(foundry_context_get_files "$context" "signed")

	for artifact in "${artifacts[@]}"; do
		local artifact_name
		local extension

		artifact_name="${artifact##*/}"
		extension="${artifact_name##*.}"

		if [[ "$extension" != "deb" ]]; then
			log_debug "Skipping non-deb artifact $artifact_name"
			continue
		fi

		if process_new_package "$context" "$artifact" "$repo" "$codename"; then
			distributed+=("$artifact_name")
		else
			log_error "Could not distribute $artifact_name"
		fi
	done

	if (( ${#distributed[@]} == 0 )); then
		log_error "No artifacts distributed"
		return 1
	fi

	if ! publish_result "$endpoint" "$publish_to" "$repository" "$branch" \
	                    "$ref" "$repo" "${distributed[@]}"; then
		log_error "Failed to publish results for $context"
		return 1
	fi

	return 0
}

watch_new_packages() {
	local endpoint_name="$1"
	local watch="$2"
	local publish_to="$3"
	local repo="$4"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not listen on IPC endpoint $endpoint_name"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "$watch"; then
		log_error "Could not subscribe to $watch"
		return 1
	fi

	while inst_running; do
		local msg
		local signmsg
		local msgtype

		inst_set_status "Waiting for sign messages"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! signmsg=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping message without data"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$signmsg"); then
			log_warn "Dropping message without type"
			continue
		fi

		if [[ "$msgtype" != "sign" ]]; then
			log_warn "Dropping message with unexpected type $msgtype"
			continue
		fi

		process_sign_message "$repo" "$signmsg" "$endpoint" "$publish_to"
	done

	return 0
}

looks_like_a_repository() {
	local path="$1"

	if ! [ -d "$path" ]; then
		return 1
	fi

	if ! [ -d "$path/incoming" ]; then
		return 1
	fi

	return 0
}

_add_arch() {
	# local name="$1" # unused
	local value="$2"

	# `architectures' is inherited from main()
	architectures+=("$value")

	return 0
}

_add_codename() {
	# local name="$1" # unused
	local value="$2"

	local branch
	local codename

	if [[ "$value" == *":"* ]]; then
		branch="${value%%:*}"
		codename="${value##*:}"
	else
		branch="*"
		codename="$value"
	fi

	# `codename_map' is inherited from main()
	if [[ -n "${codename_map[$branch]}" ]]; then
		log_error "Mapping from $branch to ${codename_map[$branch]} exists"
		return 1
	fi

	codename_map["$branch"]="$codename"
	return 0
}

main() {
	local path
	local -A codename_map
	local endpoint
	local watch
	local publish_to
	local name
	local architectures
	local gpgkey
	local desc
	local proto

	architectures=()

	opt_add_arg "e" "endpoint"    "v"  "pub/distbot" "The IPC endpoint to listen on"
	opt_add_arg "w" "watch"       "v"  "signs"       \
		    "The topic to watch for sign messages"
	opt_add_arg "p" "publish-to"  "v"  "dists"       \
		    "The topic to publish dist messages under"

	opt_add_arg "n" "name"        "rv" ""            "The name of the repository"
	opt_add_arg "o" "output"      "rv" ""            "The path to the repository"
	opt_add_arg "c" "codename"    "rv" ""            \
		    "Distribution codename (may be used more than once)"   "" _add_codename
	opt_add_arg "a" "arch"        "rv" ""            \
		    "Repository architecture (may be used more than once)" "" _add_arch
	opt_add_arg "k" "gpg-key"     "rv" ""            \
		    "The GPG key used for signing"
	opt_add_arg "d" "description" "rv" ""            \
		    "Description of the repository"
	opt_add_arg "P" "proto"       "v"  "uipc"        \
	            "The IPC flavor to use" '^u?ipc$'

	if ! opt_parse "$@"; then
		return 1
	fi

	path=$(opt_get "output")
	endpoint=$(opt_get "endpoint")
	watch=$(opt_get "watch")
	publish_to=$(opt_get "publish-to")
	name=$(opt_get "name")
	gpgkey=$(opt_get "gpg-key")
	desc=$(opt_get "description")
	proto=$(opt_get "proto")

	if ! include "$proto"; then
		return 1
	fi

	if ! looks_like_a_repository "$path"; then
		# Create new repository
		log_info "Initializing repository $name in $path"

		if ! repo_init "$path" "$name" "${architectures[*]}" \
		               "$gpgkey" "$desc" "${codename_map[@]}"; then
			log_error "Could not initialize repository"
			return 1
		fi
	fi

	inst_start watch_new_packages "$endpoint" "$watch" "$publish_to" "$path"

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "queue" "inst" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
