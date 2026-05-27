#!/bin/bash

# foundry/msg/log - Foundry log message module for toolbox
# Copyright (C) 2021-2026 Matthias Kruk
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

	declare -gxr __foundry_msg_log_msgtype="log"

	return 0
}

foundry_msg_log_new() {
	local level="$1"
	local timestamp="$2"
	local sender="$3"
	local pid="$4"
	local host="$5"
	local debug="$6"
	local lines=("${@:7}")

	local message
	local json
	local msg

	message=$(json_array "${lines[@]}")

	if ! json=$(json_object "level"     "$level"     \
				"timestamp" "$timestamp" \
				"sender"    "$sender"    \
				"pid"       "$pid"       \
				"host"      "$host"      \
				"debug"     "$debug"     \
				"message"   "$message"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_log_msgtype" "$json"); then
		return 1
	fi

	printf '%s\n' "$msg"
	return 0
}

foundry_msg_log_get_level() {
	local msg="$1"

	foundry_msg_log_get "$msg" "level"
}

foundry_msg_log_get_timestamp() {
	local msg="$1"

	foundry_msg_log_get "$msg" "timestamp"
}

foundry_msg_log_get_sender() {
	local msg="$1"

	foundry_msg_log_get "$msg" "sender"
}

foundry_msg_log_get_pid() {
	local msg="$1"

	foundry_msg_log_get "$msg" "pid"
}

foundry_msg_log_get_host() {
	local msg="$1"

	foundry_msg_log_get "$msg" "host"
}

foundry_msg_log_get_debug() {
	local msg="$1"

	foundry_msg_log_get "$msg" "debug"
}

foundry_msg_log_get() {
	local msg="$1"
	local field="$2"

	local value

	if ! value=$(foundry_msg_get_data_field "$msg" "$field"); then
		return 1
	fi

	if [[ "$field" == "message" ]]; then
		json_array_to_lines "$value"
	else
		printf '%s\n' "$value"
	fi

	return 0
}
