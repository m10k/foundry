#!/bin/bash

publish_test_result() {
	local context="$1"
	local repository="$2"
	local result="$3"
	local branch="$4"

	local message
	local endpoint
	local err

	err=0

	if ! message=$(foundry_msg_test_new "$context"    \
					    "$repository" \
					    "$branch"     \
					    "$result"); then
		log_error "Could not create test message"
		return 1
	fi

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "tests" "$message"; then
		log_error "Could not publish test result"
		err=1
	fi

	if ! ipc_endpoint_close "$endpoint"; then
		log_error "Could not close IPC endpoint"
	fi

	return "$err"
}

main() {
	local context
	local repository
	local result
	local branch

	opt_add_arg "c" "context"    "rv" "" "The context the test was performed in"
	opt_add_arg "r" "repository" "rv" "" "The repository that was tested"
	opt_add_arg "e" "result"     "rv" 0  "The result of the test"
	opt_add_arg "b" "branch"     "rv" "" "The branch that was tested"

	if ! opt_parse "$@"; then
		return 1
	fi

	context=$(opt_get "context")
	repository=$(opt_get "repository")
	result=$(opt_get "result")
	branch=$(opt_get "branch")

	if ! publish_test_result "$context" "$repository" "$result" "$branch"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "ipc" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
