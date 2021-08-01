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
		local ctx
		local result

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! fmsg=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping invalid message (not a foundry message)"
			continue
		fi

		if ! ctx=$(foundry_msg_test_get_context "$fmsg"); then
			log_warn "Dropping invalid message (no context in message)"
			continue
		fi

		if [[ "$ctx" != "$context" ]]; then
			# Unrelated message
			continue
		fi

		if ! result=$(foundry_msg_test_get_result "$fmsg"); then
			log_warn "Could not get result from test message"
			return 1
		fi

		foundry_context_get_logs "$context" | log_highlight "Test logs"

		return "$result"
	done

	return 1
}

test_testbot() {
	local repository="$1"
	local branch="$2"

	local endpoint
	local testreq
	local context

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "tests"; then
		log_error "Could not subscribe to tests"
		return 1
	fi

	if ! context=$(foundry_context_new); then
		log_error "Could not make a new foundry context"
		return 1
	fi

	if ! testreq=$(foundry_msg_testrequest_new "$context"    \
						   "$repository" \
						   "$branch"); then
		log_error "Could not make testrequest message"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/testbot" "$testreq"; then
		log_error "Could not send testrequest"
		return 1
	fi

	if ! check_result "$endpoint" "$context"; then
		return 1
	fi

	return 0
}

main() {
	local repository
	local branch

	opt_add_arg "r" "repository" "rv" "" "The repository to be tested"
	opt_add_arg "b" "branch"     "rv" "" "The branch to be tested"

	if ! opt_parse "$@"; then
		return 1
	fi

	repository=$(opt_get "repository")
	branch=$(opt_get "branch")

	if ! test_testbot "$repository" "$branch"; then
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
