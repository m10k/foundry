#!/bin/bash

# foundry/msg - Foundry message module for toolbox
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
	local submodules
	local deps

	submodules=(
		"foundry/msg/artifact"
		"foundry/msg/build"
		"foundry/msg/commit"
		"foundry/msg/dist"
		"foundry/msg/merge"
		"foundry/msg/sign"
		"foundry/msg/test"
	)

	deps=(
		"json"
	)

	if ! include "${submodules[@]}" "${deps[@]}"; then
		return 1
	fi

	declare -gxir __foundry_msg_version=1

	declare -gxir __foundry_msg_type_build=1
	declare -gxir __foundry_msg_type_commit=2
	declare -gxir __foundry_msg_type_dist=3
	declare -gxir __foundry_msg_type_merge=4
	declare -gxir __foundry_msg_type_sign=5
	declare -gxir __foundry_msg_type_test=6

	declare -gxA __foundry_msg_typemap

	__foundry_msg_typemap["build"]="$__foundry_msg_type_build"
	__foundry_msg_typemap["commit"]="$__foundry_msg_type_commit"
	__foundry_msg_typemap["dist"]="$__foundry_msg_type_dist"
	__foundry_msg_typemap["merge"]="$__foundry_msg_type_merge"
	__foundry_msg_typemap["sign"]="$__foundry_msg_type_sign"
	__foundry_msg_typemap["test"]="$__foundry_msg_type_test"

	return 0
}

foundry_msg_get_version() {
	local msg="$1"

	local version

	if ! version=$(json_object_get "$msg" "version"); then
		return 1
	fi

	echo "$version"
	return 0
}

foundry_msg_get_type() {
	local msg="$1"

	local type

	if ! type=$(json_object_get "$msg" "type"); then
		return 1
	fi

	echo "$type"
	return 0
}

foundry_msg_get_data() {
	local msg="$1"

	local data

	if ! data=$(json_object_get "$msg" "data"); then
		return 1
	fi

	echo "$data"
	return 0
}

foundry_msg_get_data_field() {
	local msg="$1"
	local field="$2"

	local value

	if ! value=$(json_object_get "$msg" "data.$field"); then
		return 1
	fi

	echo "$value"
	return 0
}

_foundry_msg_version_supported() {
	local basemsg="$1"

	local version

	if ! version=$(foundry_msg_get_version "$basemsg"); then
		return 1
	fi

	if (( version != __foundry_msg_version )); then
		return 1
	fi

	return 0
}

foundry_msg_new() {
	local type="$1"
	local data="$2"

	local msg

	if ! msg=$(json_object "version" "i:$__foundry_msg_version" \
			       "type" "s:$type"                     \
			       "data" "o:$data"); then
		return 1
	fi

	echo "$msg"
	return 0
}
