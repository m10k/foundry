#!/bin/bash

# foundry.sh - Start/stop script for the Foundry build system
# Copyright (C) 2021-2023 Matthias Kruk
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

start_daemon() {
	local daemon="$1"
	local -n args="$2"

	local arg
	local escaped_args

	escaped_args=("$daemon")
	for arg in "${args[@]}"; do
		escaped_args+=("\"$arg\"")
	done

	log_info "Starting daemon: ${escaped_args[*]}"
	"$daemon" "${args[@]}"
	return 0
}

start_group() {
	local daemon="$1"
	local -n members="$2"

	local member

	log_info "Starting group $daemon"

	for member in "${!members[@]}"; do
		if ! start_daemon "$daemon" "${members[$member]}"; then
			return 1
		fi
	done

	return 0
}

stop_group() {
	local daemon="$1"
	local -n members="$2"

	local pid
	local dontcare
	local -i err

	err=0

	while read -r pid dontcare; do
		if ! "$daemon" --stop "$pid"; then
			err=1
		fi
	done < <("$daemon" --list)

	return "$err"
}

do_error() {
	log_error "Invalid combination of arguments"
	return 2
}

do_start() {
	local config="$1"

	local group

	if ! . "$config"; then
		return 1
	fi

	for group in "${!foundry[@]}"; do
		if ! start_group "$group" "${foundry[$group]}"; then
			do_stop "$config"
			return 1
		fi
	done

	return 0
}

do_stop() {
	local config="$1"

	local group
	local -i err

	if ! . "$config"; then
		return 1
	fi

	err=0

	for group in "${!foundry[@]}"; do
		if ! stop_group "$group" "${foundry[$group]}"; then
			err=1
		fi
	done

	return "$err"
}

do_restart() {
	local config="$1"

	if do_stop "$config" &&
	   do_start "$config"; then
		return 0
	fi

	return 1
}

main() {
	local args=("$@")

	local -A foundry

	local -ri ACTION_ERROR=0
        local -ri ACTION_START=1
        local -ri ACTION_STOP=2
        local -ri ACTION_RESTART=3

	local config
	local -i start
	local -i stop
	local -i restart
	local -A actions
	local -i action

	opt_add_arg "c" "config"  "v" "/etc/foundry.conf" "Path to the foundry configuration"
	opt_add_arg "s" "start"   ""  0                   "Start foundry"
	opt_add_arg "t" "stop"    ""  0                   "Stop foundry"
	opt_add_arg "r" "restart" ""  0                   "Restart foundry"

	if ! opt_parse "${args[@]}"; then
		return 1
	fi

	config=$(opt_get "config")
	start=$(opt_get "start")
	stop=$(opt_get "stop")
	restart=$(opt_get "restart")

	action=$((
			((start   > 0) * ACTION_START  ) +
			((stop    > 0) * ACTION_STOP   ) +
			((restart > 0) * ACTION_RESTART)
		))

	actions["$action"]=do_error
	actions["$ACTION_ERROR"]=do_error
	actions["$ACTION_START"]=do_start
	actions["$ACTION_STOP"]=do_stop
	actions["$ACTION_RESTART"]=do_restart

	"${actions[$action]}" "$config"
	return "$?"
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
