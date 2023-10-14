#!/bin/bash

# repobot.sh - Publish RPMs in a YUM repository
# Copyright (C) 2023 Cybertrust Japan Co., Ltd.
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

get_repository() {
	local dist="$1"
	local arch="$2"

	local repo

	repo="${repository_map[$dist:$arch]}"

	if [[ -n "$repo" ]]; then
		printf '%s\n' "$repo"
		return 0
	fi

	return 1
}

get_repository_for() {
	local dist="$1"
	local arch="$2"

	if ! get_repository "$dist" "$arch" &&
	   ! get_repository "$dist" "*"     &&
	   ! get_repository "*"     "*"; then
		return 1
	fi

	return 0
}

handle_build() {
	local build="$1"
	local architecture="$2"
	local distribution="$3"
	local context="$4"
	local endpoint="$5"

	local context_dir
	local artifact
	local repository

	context_dir="$(foundry_context_get_root)/$context"
	if ! repository=$(get_repository_for "$distribution" "$architecture"); then
		log_error "No repository for $distribution:$architecture"
		return 1
	fi

	if ! mkdir -p "$repository"; then
		log_error "Could not create $repository"
		return 1
	fi

	while read -r artifact; do
		if ! [[ "$artifact" == *".rpm" ]]; then
			continue
		fi

		log_info "Adding $artifact to $repository"
		if ! cp "$artifact" "$repository/."; then
			log_error "Could not copy $artifact to $repository"
			return 1
		fi
	done < <(foundry_build_list_files "$build" "$context_dir/files/results/mock")

	log_info "Updating metadata for $repository"
	if ! createrepo "$repository"; then
		log_error "Could not create metadata for $repository"
		return 1
	fi

	return 0
}

handle_build_result() {
	local endpoint="$1"
	local buildresult="$2"

	local architecture
	local distribution
	local context

	if ! architecture=$(foundry_buildresult_get_architecture "$buildresult"); then
		log_error "Could not get architecture from buildresult"
		return 1
	fi

	if ! distribution=$(foundry_buildresult_get_distribution "$buildresult"); then
		log_error "Could not get distribution from buildresult"
		return 1
	fi

	if ! context=$(foundry_buildresult_get_context "$buildresult"); then
		log_error "Could not get context from buildresult"
		return 1
	fi

	foundry_buildresult_foreach_build "$buildresult" handle_build "$architecture" \
	                                  "$distribution" "$context" "$endpoint"
	return "$?"
}

handle_message() {
	local endpoint="$1"
	local message="$2"

	local type
	local build_result

	inst_set_status "Handling build result"
	type=$(foundry_msgv2_get_type "$message")

	if [[ "$type" != "foundry.msg.build.result" ]]; then
		log_warn "Dropping message of type $type"
		return 0
	fi

	build_result=$(foundry_msgv2_get_buildresult "$message")
	handle_build_result "$endpoint" "$build_result"

	return 0
}

run_repobot() {
	local input_topic="$1"

	local endpoint

	if ! endpoint=$(foundry_common_make_endpoint "" "$input_topic"); then
		return 1
	fi

	while inst_running; do
		local msg
		local data

		inst_set_status "Waiting for requests"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		data=$(ipc_msg_get_data "$msg")
		handle_message "$endpoint" "$data"
	done

	if ! ipc_endpoint_close "$endpoint"; then
		log_warn "Could not close endpoint $endpoint"
	fi

	return 0
}

add_repository_mapping() {
	local name="$1"
	local value="$2"

	local re
	local dist
	local arch
	local repo

	re='^([^:]+):([^:]+):(.+)$'

	if ! [[ "$value" =~ $re ]]; then
		log_error "Mapping must have format \"distro:architecture:repository\""
		return 1
	fi

	dist="${BASH_REMATCH[1]}"
	arch="${BASH_REMATCH[2]}"
	repo="${BASH_REMATCH[3]}"

	# repository_map is declared in main()
	repository_map["$dist:$arch"]="$repo"

	return 0
}

main() {
        declare -gxA repository_map

	opt_add_arg "I" "input-topic"   "v"   "foundry.build.succeeded" \
	            "The topic to listen for build announcements on"
	opt_add_arg "O" "output-topic"  "v"   "foundry.repo.updated"    \
	            "The topic to announce repository updates to"
	opt_add_arg "F" "failure-topic" "v"   "foundry.repo.failed"     \
	            "The topic to announce repository update failures to"
	opt_add_arg "E" "error-topic"   "v"   "foundry.errors"          \
	            "The topic to send error messages to"
	opt_add_arg "p" "protocol"      "v"   "uipc"                    \
	            "The IPC flavor to use"
	opt_add_arg "r" "repository"    "vr" ""                         \
	            "Add mapping for package sorting"                   \
		    '' add_repository_mapping

	if ! opt_parse "$@"; then
		return 1
	fi

	input_topic=$(opt_get "input-topic")
	protocol=$(opt_get "protocol")

	if ! include "$protocol"; then
		return 1
	fi

	if ! inst_start run_repobot "$input_topic"; then
		return 2
	fi

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "inst"    \
	             "foundry/common"      \
	             "foundry/context"     \
	             "foundry/msgv2"       \
	             "foundry/sourceref"   \
	             "foundry/checksum"    \
	             "foundry/stats"       \
	             "foundry/timestamp"   \
	             "foundry/buildresult" \
	             "foundry/build"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
