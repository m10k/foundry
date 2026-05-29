#!/bin/bash

# foundry/bot - Foundry bot module for toolbox
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
	if ! include "uipc" "inst" "foundry/log"; then
		return 1
	fi

	declare -gx  __foundry_bot_endpoint
	declare -gxA __foundry_bot_topic_handlers

	declare -gxA __foundry_bot_timer_handlers
	declare -gxA __foundry_bot_timer_intervals
	declare -gxA __foundry_bot_timer_remaining

	declare -gxi __foundry_bot_timer_last_check

	return 0
}

foundry_bot_init() {
	local endpoint_name="$1"

	if [[ -z "$__foundry_bot_endpoint" ]]; then
		local endpoint

		if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
			return 1
		fi

		__foundry_bot_endpoint="$endpoint"
		foundry_log_set_endpoint "$endpoint"
	fi

	return 0
}

foundry_bot_register_handler() {
	local handler="$1"
	local topic="$2"
	local args=("${@:3}")

	if ! foundry_bot_init ||
	   ! ipc_endpoint_subscribe "$__foundry_bot_endpoint" "$topic"; then
		return 1
	fi

	declare -gxa "__foundry_bot_topic_args_$topic"
	local -n argref="__foundry_bot_topic_args_$topic"

	__foundry_bot_topic_handlers["$topic"]="$handler"
	argref=("${args[@]}")

	return 0
}

foundry_bot_register_timer() {
	local handler="$1"
	local -i interval="${2-1}"
	local args=("${@:3}")

	# Associative arrays cannot be used to store arrays,
	# so we have to get creative: We declare a unique
	# argument array for each timer that was registered

	local -i timer_id="${#__foundry_bot_timer_handlers[@]}"
	log_debug "New timer has id $timer_id ($handler, $interval)"
	declare -gxa "__foundry_bot_timer_args_$timer_id"
	local -n argref="__foundry_bot_timer_args_$timer_id"

	# shellcheck disable=SC2034 # Shellcheck doesn't handle namerefs properly
	argref=("${args[@]}")

	__foundry_bot_timer_handlers["$timer_id"]="$handler"
	__foundry_bot_timer_remaining["$timer_id"]="$interval"
	__foundry_bot_timer_intervals["$timer_id"]="$interval"

	return 0
}

_foundry_bot_call_timers() {
	local -i elapsed
	local -i timer_id

	if (( __foundry_bot_timer_last_check == 0 )); then
		__foundry_bot_timer_last_check=EPOCHSECONDS
		return 0
	fi

	elapsed=$((EPOCHSECONDS - __foundry_bot_timer_last_check))
	__foundry_bot_timer_last_check=EPOCHSECONDS

	for timer_id in "${!__foundry_bot_timer_handlers[@]}"; do
		local handler
		local -i remaining
		local -i interval

		handler="${__foundry_bot_timer_handlers["$timer_id"]}"
		remaining="${__foundry_bot_timer_remaining["$timer_id"]}"
		interval="${__foundry_bot_timer_intervals["$timer_id"]}"

		log_debug "Timer $timer_id is $handler ($remaining / $interval)"

		(( remaining -= elapsed ))

		if (( remaining <= 0 )); then
			# shellcheck disable=SC2178 # Shellcheck doesn't handle namerefs properly
			local -n args="__foundry_bot_timer_args_$timer_id"

			"$handler" "${args[@]}"
			remaining=interval
		fi

		__foundry_bot_timer_remaining["$timer_id"]="$remaining"
	done

	return 0
}

_foundry_bot_run() {
	if ! foundry_bot_init; then
		return 1
	fi

	while inst_running; do
		local msg
		local topic

		if msg=$(ipc_endpoint_recv "$__foundry_bot_endpoint" 1) &&
		   topic=$(ipc_msg_get_topic "$msg") &&
		   [[ -n "${__foundry_bot_topic_handlers[$topic]}" ]]; then
			local -n args="__foundry_bot_topic_args_$topic"

			"${__foundry_bot_topic_handlers[$topic]}" "$msg" "${args[@]}"
		fi

		_foundry_bot_call_timers
	done

	return 0
}

foundry_bot_run() {
	inst_start _foundry_bot_run
}

foundry_bot_publish() {
	local topic="$1"
	local msg="$2"

	if ! foundry_bot_init; then
		return 1
	fi

	ipc_endpoint_publish "$__foundry_bot_endpoint" "$topic" "$msg"
}
