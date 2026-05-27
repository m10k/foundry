#!/bin/bash

# foundry/log - Foundry log module for toolbox
# Copyright (C) 2026 Matthias Kruk
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
	if ! include "log" "foundry/msg/log"; then
		return 1
	fi

	declare -xgri __foundry_log_debug=3
	declare -xgri __foundry_log_info=2
	declare -xgri __foundry_log_warning=1
	declare -xgri __foundry_log_error=0

	declare -xg   __foundry_log_topic="messages"
	declare -xg   __foundry_log_endpoint=""

	return 0
}

foundry_log_set_endpoint() {
	local endpoint="$1"

	__foundry_log_endpoint="$endpoint"
	return 0
}

foundry_log_set_topic() {
	local topic="$1"

	__foundry_log_topic="$topic"
	return 0
}

_foundry_log_write() {
	local level="$1"
	local tag="$2"
	local lines=("${@:3}")

	local line
	local msg
	local timestamp

	timestamp="$EPOCHREALTIME"

	if [[ -z "$__foundry_log_endpoint" ]]; then
		log_error "IPC endpoint has not been set"
		return 1
	fi

	if (( ${#lines[@]} == 0 )); then
		while IFS='' read -r line; do
			lines+=("$line")
		done
	fi

	if ! msg=$(foundry_msg_log_new "$level"     \
	                               "$timestamp" \
	                               "$USER"      \
	                               "$$"         \
	                               "$HOSTNAME"  \
	                               "$tag"       \
	                               "${lines[@]}"); then
		return 2
	fi

	if ! ipc_endpoint_publish "$__foundry_log_endpoint" "$__foundry_log_topic" "$msg"; then
		log_error "Could not log to $__foundry_log_topic"
		return 3
	fi

	return 0
}

foundry_log_debug() {
	local lines=("$@")

	_foundry_log_write "$__foundry_log_debug" \
	                   "${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}" \
	                   "${lines[@]}"
}

foundry_log_info() {
	local lines=("$@")

	_foundry_log_write "$__foundry_log_info" \
	                   "${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}" \
	                   "${lines[@]}"
}

foundry_log_warn() {
	local lines=("$@")

	_foundry_log_write "$__foundry_log_warning" \
	                   "${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}" \
	                   "${lines[@]}"
}

foundry_log_error() {
	local lines=("$@")

	_foundry_log_write "$__foundry_log_error" \
	                   "${BASH_SOURCE[1]}:${BASH_LINENO[1]}:${FUNCNAME[1]}" \
	                   "${lines[@]}"
}
