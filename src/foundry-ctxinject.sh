#!/bin/bash

# foundry-ctxinject.sh - Context injector hook for ipc-inject
# Copyright (C) 2022 Matthias Kruk
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

receive_context() (
	local data="$1"

	local context_root

	context_root=$(foundry_context_get_root)

	if ! cd "$context_root"; then
		return 1
	fi

	base64 -d <<< "$data" | tar -xj
)

handle_message() {
	local message
	local context
	local data

	if ! message=$(< /dev/stdin); then
		log_error "Could not read message"
		return 1
	fi

	if ! context=$(json_object_get "$message" "context"); then
		log_warn "Dropping message without context"
		return 1
	fi

	log_info "Received context $context"

	if ! data=$(json_object_get "$message" "data"); then
		log_warn "Dropping message without data"
		return 1
	fi

	log_info "Unpacking context $context"
	if ! receive_context "$data"; then
		return 1
	fi

	return 0
}

main() {
	local message

	if ! opt_parse "$@"; then
		return 1
	fi

	if ! handle_message; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "json" "foundry/context"; then
		return 1
	fi

	main "$@"
	exit "$?"
}
