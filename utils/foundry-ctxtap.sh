#!/bin/bash

# foundry-ctxtap.sh - Context sender hook for ipc-tap
# Copyright (C) 2022-2023 Matthias Kruk
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

create_context_archive() (
	local context="$1"

	if ! cd "$__foundry_context_root"; then
		return 1
	fi

	tar -cj "$context" 2>/dev/null | base64 -w 0
)

pack_context() {
	local fmsg="$1"

	local accepted_types
	local fmsgtype
	local context
	local data

	accepted_types=(
		"build"
		"sign"
	)

	if ! fmsgtype=$(foundry_msg_get_type "$fmsg"); then
		log_warn "Dropping malformed foundry message"
		return 1
	fi

	if ! array_contains "$fmsgtype" "${accepted_types[@]}"; then
		log_warn "Discarding $fmsgtype message"
		return 0
	fi

	if ! context=$(foundry_msg_get_data_field "$fmsg" "context"); then
		log_warn "Could not get context from message"
		return 1
	fi

	log_info "Received $fmsgtype message with context $context"

	if ! data=$(create_context_archive "$context"); then
		log_error "Could not archive context $context"
		return 1
	fi

	if ! json_object "context" "$context" \
	                 "data"    "$data"; then
		log_error "Could not make JSON object"
		return 1
	fi

	return 0
}

main() {
	local message
	local archive
	local data

	if ! opt_parse "$@"; then
		return 1
	fi

	if ! message=$(< /dev/stdin); then
		return 1
	fi

	if ! archive=$(pack_context "$message"); then
		return 1
	fi

	if ! json_object "tag"  "foundry.context" \
	                 "data" "$archive"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "json" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
