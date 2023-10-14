#!/bin/bash

# foundry/build - Foundry build module for toolbox
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
	if ! include "json" "foundry/vargs" "foundry/directory"; then
		return 1
	fi

	return 0
}

foundry_build_new() {
	local args=("$@")

	local -a all_args
	local -A parsed_args
	local artifacts

	all_args=(
		"sourceref"
		"artifacts"
	)

	if ! foundry_vargs_parse args all_args all_args parsed_args; then
		return 1
	fi

	if ! artifacts=$(foundry_directory_new "${parsed_args[artifacts]}"); then
		return 2
	fi

	json_object "sourceref" "$sourceref" \
	            "artifacts" "$artifacts"
	return "$?"
}

foundry_build_get_sourceref() {
	local build="$1"

	jq -r -e '.sourceref' <<< "$build"
	return "$?"
}

foundry_build_get_artifacts() {
	local build="$1"

	jq -r -e '.artifacts' <<< "$build"
	return "$?"
}

foundry_build_list_files() {
	local build="$1"
	local prefix="$2"

	local artifacts

	if ! artifacts=$(foundry_build_get_artifacts "$build"); then
		return 1
	fi

	foundry_directory_listing "$artifacts" "$prefix"
	return "$?"
}
