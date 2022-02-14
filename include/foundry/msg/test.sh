#!/bin/bash

# foundry/msg/test - Foundry test message module for toolbox
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

	declare -gxr __foundry_msg_test_msgtype="test"

	return 0
}

foundry_msg_test_new() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local result="$4"

	local json
	local msg

	if ! json=$(json_object "context"    "$context"    \
				"repository" "$repository" \
				"branch"     "$branch"     \
				"result"     "$result"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_test_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_test_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_test_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_test_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_test_get_result() {
	local msg="$1"

	local result

	if ! result=$(foundry_msg_get_data_field "$msg" "result"); then
		return 1
	fi

	echo "$result"
	return 0
}
