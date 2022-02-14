#!/bin/bash

# foundry/msg/build - Foundry build message module for toolbox
# Copyright (C) 2021-2022 Matthias Kruk
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
	if ! include "json" "foundry/msg/artifact"; then
		return 1
	fi

	declare -gxr __foundry_msg_build_msgtype="build"

	return 0
}

foundry_msg_build_new() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local ref="$4"
	local result="$5"
	local -n __foundry_msg_build_new_artifacts="$6"

	local artifact_array
	local json
	local msg

	if ! artifact_array=$(json_array "${__foundry_msg_build_new_artifacts[@]}"); then
		return 1
	fi

	if ! json=$(json_object "context"    "$context"       \
				"repository" "$repository"    \
				"branch"     "$branch"        \
				"ref"        "$ref"           \
				"result"     "$result"        \
				"artifacts"  "$artifact_array"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_build_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_build_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_build_get_repository() {
	local msg="$1"

        local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_build_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_build_get_ref() {
	local msg="$1"

	local ref

	if ! ref=$(foundry_msg_get_data_field "$msg" "ref"); then
		return 1
	fi

	echo "$ref"
	return 0
}

foundry_msg_build_get_result() {
	local msg="$1"

	local result

	if ! result=$(foundry_msg_get_data_field "$msg" "result"); then
		return 1
	fi

	echo "$result"
	return 0
}

foundry_msg_build_get_artifacts() {
	local msg="$1"

	local query
	local raw_artifacts
	local artifacts
	local checksum
	local uri

	query='artifacts[] | "\(.checksum) \(.uri)"'
	artifacts=()

	if ! raw_artifacts=$(foundry_msg_get_data_field "$msg" "$query"); then
		return 1
	fi

	while read -r checksum uri; do
		local artifact

		if ! artifact=$(foundry_msg_artifact_new "$uri" "$checksum"); then
			return 1
		fi

		artifacts+=("$artifact")
	done <<< "$raw_artifacts"

	array_to_lines "${artifacts[@]}"
	return 0
}
