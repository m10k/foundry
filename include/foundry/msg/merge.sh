#!/bin/bash

# foundry/msg/merge - Foundry merge message module for toolbox
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
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_merge_msgtype="merge"

	return 0
}

foundry_msg_merge_new() {
	local context="$1"
	local repository="$2"
	local srcbranch="$3"
	local dstbranch="$4"
	local status="$5"

	local json
	local msg

	if ! json=$(json_object "context"    "$context"    \
				"repository" "$repository" \
				"srcbranch"  "$srcbranch"  \
				"dstbranch"  "$dstbranch"  \
				"status"     "$status"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_merge_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_merge_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_merge_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_merge_get_source_branch() {
	local msg="$1"

	local srcbranch

	if ! srcbranch=$(foundry_msg_get_data_field "$msg" "srcbranch"); then
		return 1
	fi

	echo "$srcbranch"
	return 0
}

foundry_msg_merge_get_destination_branch() {
	local msg="$1"

	local dstbranch

	if ! dstbranch=$(foundry_msg_get_data_field "$msg" "dstbranch"); then
		return 1
	fi

	echo "$dstbranch"
	return 0
}

foundry_msg_merge_get_status() {
	local msg="$1"

	local status

	if ! status=$(foundry_msg_get_data_field "$msg" "status"); then
		return 1
	fi

	echo "$status"
	return 0
}
