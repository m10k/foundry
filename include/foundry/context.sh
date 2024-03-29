#!/bin/bash

# foundry/context - Foundry context module for toolbox
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
	if ! include "log" "array"; then
		return 1
	fi

	declare -gxr __foundry_context_root="/var/lib/foundry/contexts"

	return 0
}

_foundry_context_new_id() {
	local context_name="$1"

	local timestamp
	local number

	if ! timestamp=$(date +"%Y%m%d-%H%M"); then
		return 1
	fi

	if ! number=$(printf "%04d" "$((RANDOM % 10000))"); then
		return 1
	fi

	echo "$context_name-$timestamp-$number"
	return 0
}

foundry_context_new() {
	local context_name="$1"

	local tid
	local context_path

	if ! tid=$(_foundry_context_new_id "$context_name"); then
		return 1
	fi

	context_path="$__foundry_context_root/$tid"

	if ! mkdir -p "$context_path/files" \
	              "$context_path/logs"; then
		return 1
	fi

	echo "$tid"
	return 0
}

foundry_context_remove() {
	local context="$1"

	local context_path

        context_path="$__foundry_context_root/$context"

	if [[ -z "$context" ]]; then
		return 1
	fi

	if ! rm -r "$context_path"; then
		return 1
	fi

	return 0
}

foundry_context_add_file() {
	local context="$1"
	local filetype="$2"
	local file="$3"

	local context_path
	local file_path

	context_path="$__foundry_context_root/$context"
	file_path="$context_path/$filetype"

	if ! mkdir -p "$file_path"; then
		return 1
	fi

	if ! cp "$file" "$file_path/."; then
		return 1
	fi

	return 0
}

foundry_context_get_files() {
	local context="$1"
	local file_type="$2"

	local file_dir
	local files
	local file

	# file_type may be omitted to get all files
	file_dir="$__foundry_context_root/$context/$file_type"
	files=()

	while read -r file; do
		local absolute

		if ! absolute=$(realpath "$file"); then
			continue
		fi

		files+=("$file")
	done < <(find "$file_dir" -type f)

	array_to_lines "${files[@]}"
	return 0
}

foundry_context_add_log() {
	local context="$1"
	local logtype="$2"
	local log="$3"

	local logdir

	logdir="$__foundry_context_root/$context/logs/$logtype"

	if ! mkdir -p "$logdir"; then
		return 1
	fi

	if ! cp "$log" "$logdir/."; then
		return 1
	fi

	return 0
}

foundry_context_get_logs() {
	local context="$1"
	local logtype="$2"

	local logdir
	local logs
	local log

	logdir="$__foundry_context_root/$context/logs/$logtype"
	logs=()

	while read -r log; do
		local absolute

		if ! absolute=$(realpath "$log"); then
			continue
		fi

		logs+=("$absolute")
	done < <(find "$logdir" -type f)

	array_to_lines "${logs[@]}"
	return 0
}

foundry_context_log() {
	local context="$1"
	local logtype="$2"
	local messages=("${@:3}")

	local logdir
	local logname

	logdir="$__foundry_context_root/$context/logs/$logtype"
	logname="$logdir/default.log"

	if ! mkdir -p "$logdir"; then
		return 1
	fi

	if (( ${#messages[@]} > 0 )); then
		if ! array_to_lines "${messages[@]}" >> "$logname"; then
			return 1
		fi
	else
		if ! cat /dev/stdin >> "$logname"; then
			return 1
		fi
	fi

	return 0
}

foundry_context_get_root() {
	echo "$__foundry_context_root"
}
