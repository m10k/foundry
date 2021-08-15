#!/bin/bash

check_result() {
	local endpoint="$1"
	local context="$2"

	local start
	local timelimit

	start=$(date +"%s")
	timelimit=$((5 * 60))

	while (( ( $(date +"%s") - start ) < timelimit )); do
		local msg
		local fmsg
		local msgtype
		local ctx

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! fmsg=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping invalid message (no data)"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$fmsg"); then
			log_warn "Dropping message with unexpected type \"$msgtype\""
			continue
		fi

		if ! ctx=$(foundry_msg_get_context "$fmsg"); then
			log_warn "Dropping message without context"
			continue
		fi

		if [[ "$ctx" != "$context" ]]; then
			# Unrelated
			continue
		fi

		foundry_context_get_logs "$context" | log_highlight "$context logs"
		return 0
	done

	return 1
}

prepare_context() {
	local packages=("$@")

	local name
	local context
	local package

	if (( ${#packages[@]} < 1 )); then
		log_error "No packages to distribute"
		return 1
	fi

	name="${packages[0]}"
	name="${name%%_*}"

	if ! context=$(foundry_context_new "$name"); then
		log_error "Could not create new context for $name"
		return 1
	fi

	for package in "${package[@]}"; do
		if ! foundry_context_add_file "$context" "$package"; then
			log_error "Could not add $package to context $context"
			return 1
		fi
	done

	echo "$context"
	return 0
}

send_dist_request() {
	local endpoint="$1"
	local context="$2"

	local distreq

	if ! distreq=$(foundry_msg_distrequest_new "$context"); then
		log_error "Could not make distrequest message"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/distbot" "$distreq"; then
		log_error "Could not send distrequest message to pub/distbot"
		return 1
	fi

	return 0
}

test_distbot() {
	local packages=("$@")

	local context
	local package
	local endpoint
	local name

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open an IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "dists"; then
		log_error "Could not subscribe $endpoint to dists"
		return 1
	fi

	if ! context=$(prepare_context "$name" "${packages[@]}"); then
		log_error "Could not prepare context"
		return 1
	fi

	if ! send_dist_request "$endpoint" "$context"; then
		log_error "Could not send distrequest message"
		return 1
	fi

	if ! check_result "$endpoint" "$context"; then
		return 1
	fi

	return 0
}

_add_package() {
	local name="$1"
	local value="$2"

	if [[ "$name" != "package" ]]; then
		return 1
	fi

	packages+=("$value")
	return 0
}

main() {
	local packages

	packages=()

	opt_add_arg "p" "package" "rv" "" "A package to add to distribute" "" _add_package

	if ! opt_parse "$@"; then
		return 1
	fi

	if ! test_distbot "${packages[@]}"; then
		echo "Test failed"
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "ipc" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
