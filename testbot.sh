#!/bin/bash

test_source_tree() {
	local repository="$1"
	local branch="$2"

	local destination
	local err

	if ! destination=$(mktemp -d); then
		echo "Could not create temporary directory"
		log_error "Could not create temporary directory"
		return 1
	fi

	if ! git clone "$repository" -b "$branch" --single-branch "$destination"; then
		local errmsg

		errmsg="Could not check out $repository#$branch to $destination"
		log_error "$errmsg"
		echo "$errmsg"

		if ! rm -rf "$destination"; then
			log_warn "Could not remove $destination"
			echo "Could not remove $destination"
		fi

		return 1
	fi

	err=0

	if ! ( cd "$destination" && make test ) 2>&1; then
		err=1
	fi

	if ! rm -rf "$destination"; then
		log_warn "Could not remove temporary directory $destination"
		echo "Could not remove temporary directory $destination"
	fi

	return "$err"
}

publish_result() {
	local endpoint="$1"
	local topic="$2"
	local context="$3"
	local repository="$4"
	local branch="$5"
	local result="$6"

	local testmsg

	if ! testmsg=$(foundry_msg_test_new "$context"    \
					    "$repository" \
					    "$branch"     \
					    "$result"); then
		log_error "Could not make test message"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$testmsg"; then
		log_error "Could not publish test message on $topic"
		return 1
	fi

	return 0
}

handle_test_request() {
	local endpoint="$1"
	local request="$2"
	local topic="$3"

	local context
	local repository
	local branch
	local result
	local testlog

	if ! context=$(foundry_msg_testrequest_get_context "$request"); then
		log_warn "Could not get context from message. Dropping."
		return 1

	elif ! repository=$(foundry_msg_testrequest_get_repository "$request"); then
		log_warn "Could not get repository from message. Dropping."
		return 1

	elif ! branch=$(foundry_msg_testrequest_get_branch "$request"); then
		log_warn "Could not get branch from message. Dropping."
		return 1
	fi

	result=0
	if ! testlog=$(mktemp --suffix="-test.log"); then
		log_error "Could not create logfile"
		return 1
	fi

	if ! test_source_tree "$repository" "$branch" &> "$testlog"; then
		result=1
	fi

	if ! foundry_context_add_log "$context" "test" "$testlog"; then
		log_error "Could not add logfile to context $context"

		if ! rm -f "$testlog"; then
			log_warn "Could not remove $testlog"
		fi

		return 1
	fi

	if ! publish_result "$endpoint" "$topic" "$context" \
	                    "$repository" "$branch" "$result"; then
		log_warn "Could not publish test result"
		return 1
	fi

	return 0
}

_testbot_run() {
	local endpoint_name="$1"
	local topic="$2"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not listen on $endpoint_name"
		return 1
	fi

	while inst_running; do
		local msg
		local fmsg
		local ftype

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! fmsg=$(ipc_msg_get_data "$msg") ||
		   ! ftype=$(foundry_msg_get_type "$fmsg") ||
		   [[ "$ftype" != "testrequest" ]]; then
			log_warn "Dropping invalid message"
			continue
		fi

		handle_test_request "$endpoint" "$fmsg" "$topic"
	done

	return 0
}

main() {
	local endpoint_name
	local topic

	opt_add_arg "n" "name"     "rv" ""            \
		    "The name of this instance"
	opt_add_arg "e" "endpoint" "v"  "pub/testbot" \
		    "The endpoint to use for IPC messaging"
	opt_add_arg "t" "topic"    "v"  "tests"       \
		    "The topic under which to publish notifications"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint_name=$(opt_get "endpoint")
	topic=$(opt_get "topic")

	if ! inst_start _testbot_run "$endpoint_name" "$topic"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "ipc" "inst" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
