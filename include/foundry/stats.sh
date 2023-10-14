#!/bin/bash

# foundry/stats - Foundry build stats module for toolbox
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
	if ! include "is" "json" "foundry/vargs" "foundry/timestamp"; then
		return 1
	fi

	return 0
}

foundry_stats_new() {
	local args=("$@")

	local -a all_args
	local -A parsed_args
	local key

	all_args=(
		"start_time"
		"end_time"
		"memory"
		"disk"
	)

	if ! foundry_vargs_parse args all_args all_args parsed_args; then
		return 1
	fi

	# Convert UNIX timestamps to ISO8601 format
	for key in "start_time" "end_time"; do
		if is_digits "${parsed_args["$key"]}"; then
			parsed_args["$key"]=$(foundry_timestamp_from_unix "${parsed_args["$key"]}")
		fi
	done


	json_object "start_time" "${parsed_args[start_time]}" \
	            "end_time"   "${parsed_args[end_time]}"   \
	            "memory"     "${parsed_args[memory]}"     \
	            "disk"       "${parsed_args[disk]}"
	return "$?"
}

foundry_stats_get_start_time() {
	local stats="$1"

	jq -r -e '.start_time' <<< "$stats"
	return "$?"
}

foundry_stats_get_end_time() {
	local stats="$1"

	jq -r -e '.end_time' <<< "$stats"
	return "$?"
}

foundry_stats_get_memory() {
	local stats="$1"

	jq -r -e '.memory' <<< "$stats"
	return "$?"
}

foundry_stats_get_disk() {
	local stats="$1"

	jq -r -e '.disk' <<< "$stats"
	return "$?"
}

foundry_stats_get_elapsed_seconds() {
	local stats="$1"

	local start_time
	local end_time
	local -i start_time_unix
	local -i end_time_unix
	local -i elapsed_seconds

	if ! start_time=$(foundry_stats_get_start_time "$stats") ||
	   ! end_time=$(foundry_stats_get_end_time "$stats"); then
		return 1
	fi

	if ! start_time_unix=$(foundry_timestamp_to_unix "$start_time") ||
	   ! end_time_unix=$(foundry_timestamp_to_unix "$end_time"); then
		return 1
	fi

	elapsed_seconds=$((end_time_unix - start_time_unix))
	echo "$elapsed_seconds"
	return 0
}
