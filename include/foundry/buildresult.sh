#!/bin/bash

# foundry/buildresult - Module for foundry build results
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

__init() {
	if ! include "json" "foundry/vargs"; then
		return 1
	fi

	return 0
}

foundry_buildresult_new() {
	local args=("$@")

	local -a all_args
	local -A parsed_args
	local -n ___builds
	local builds_json

	all_args=(
		"status"
		"context"
		"builds"
		"host"
		"process"
		"stats"
		"architecture"
		"distribution"
	)

	if ! foundry_vargs_parse args all_args all_args parsed_args; then
		return 1
	fi

	___builds="${parsed_args[builds]}"
	builds_json=$(json_array "${___builds[@]}")

	json_object "status"       "${parsed_args[status]}"       \
	            "context"      "${parsed_args[context]}"      \
	            "builds"       "$builds_json"                 \
	            "host"         "${parsed_args[host]}"         \
	            "process"      "${parsed_args[process]}"      \
	            "stats"        "${parsed_args[stats]}"        \
	            "architecture" "${parsed_args[architecture]}" \
	            "distribution" "${parsed_args[distribution]}"
	return "$?"
}

foundry_buildresult_get_status() {
	local buildresult="$1"

	jq -e -r ".status" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_context() {
	local buildresult="$1"

	jq -e -r ".context" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_architecture() {
	local buildresult="$1"

	jq -e -r ".architecture" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_host() {
	local buildresult="$1"

	jq -e -r ".host" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_stats() {
	local buildresult="$1"

	jq -e -r ".stats" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_process() {
	local buildresult="$1"

	jq -e -r ".process" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_get_distribution() {
	local buildresult="$1"

	jq -e -r ".distribution" <<< "$buildresult"
	return "$?"
}

foundry_buildresult_foreach_build() {
	local buildresult="$1"
	local userfunc="$2"
	local -a userdata=("${@:3}")

	local -i num_builds
	local -i i

	num_builds=$(jq -e -r '.builds[] | length' <<< "$buildresult")

	for (( i = 0; i < num_builds; i++ )); do
		local build
		local -i ret_val

		if ! build=$(jq -e -r ".builds[$i]" <<< "$buildresult"); then
			return 1
		fi

		"$userfunc" "$build" "${userdata[@]}"
		ret_val="$?"

		if (( ret_val != 0 )); then
			return "$ret_val"
		fi
	done

	return 0
}
