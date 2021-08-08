#!/bin/bash

merge() {
	local repository="$1"
	local sbranch="$2"
	local dbranch="$3"

	local clone
	local msg
	local err

	if ! clone=$(mktemp -d); then
		msg="Could not make temporary directory"
		log_error "$msg"
		echo "$msg"
		return 1
	fi

	err=1

	if ! git_clone "$repository" "$clone"; then
		msg="Could not clone $repository into $clone"
		log_error "$msg"
		echo "$msg"

	elif ! git_merge "$clone" "$sbranch" "$dbranch"; then
		msg="Could not merge $sbranch into $dbranch in $repository"
		log_error "$msg"
		echo "$msg"

	elif ! git_push "$clone" "$dbranch"; then
		msg="Could not push branch \"$dbranch\" of $repository to origin"
		log_error "$msg"
		echo "$msg"

	else
		err=0
	fi

	if ! rm -rf "$clone"; then
		msg="Could not clean up temporary directory $clone"
		log_warn "$msg"
		echo "$msg"
	fi

	return "$err"
}

handle_merge_request() {
	local endpoint="$1"
	local topic="$2"
	local mmsg="$3"

	local context
	local repository
	local sbranch
	local dbranch
	local mergelog
	local result
	local merge_msg

	if ! context=$(foundry_msg_mergerequest_get_context "$mmsg") ||
	   ! repository=$(foundry_msg_mergerequest_get_repository "$mmsg") ||
	   ! sbranch=$(foundry_msg_mergerequest_get_source_branch "$mmsg") ||
	   ! dbranch=$(foundry_msg_mergerequest_get_destination_branch "$mmsg"); then
		log_warn "Dropping malformed message"
		log_highlight "message" <<< "$mmsg" | log_debug
		return 1
	fi

	result=0

	if ! mergelog=$(merge "$repository" "$sbranch" "$dbranch"); then
		result=1
	fi

	if ! foundry_context_log "$context" "merge" <<< "$mergelog"; then
		log_error "Could not log to context $context"
	fi

	if ! merge_msg=$(foundry_msg_merge_new "$context" \
					       "$repository" \
					       "$sbranch" \
					       "$dbranch" \
					       "$result"); then
		log_error "Could not create merge message"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$merge_msg"; then
		return 1
	fi

	return 0
}

handle_message() {
	local endpoint="$1"
	local topic="$2"
	local message="$3"

	local mmsg
	local msgtype

	if ! mmsg=$(ipc_msg_get_data "$message"); then
		log_warn "Dropping malformed message"
		ipc_msg_dump "$message" | log_warn
		return 1
	fi

	if ! msgtype=$(foundry_msg_get_type "$mmsg"); then
		log_warn "Dropping message without type"
		return 1
	fi

	if [[ "$msgtype" != "mergerequest" ]]; then
		log_warn "Dropping message with unexpected type $msgtype"
		return 1
	fi

	if ! handle_merge_request "$endpoint" "$topic" "$mmsg"; then
		return 1
	fi

	return 0
}

_mergebot_run() {
	local endpoint_name="$1"
	local topic="$2"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open endpoint $endpoint_name"
		return 1
	fi

	while inst_running; do
		local msg

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		handle_message "$endpoint" "$topic" "$msg"
	done

	return 0
}

main() {
	local endpoint
	local topic

	opt_add_arg "e" "endpoint" "v" "pub/mergebot" "The endpoint to receive messages on"
	opt_add_arg "t" "topic"    "v" "merges"       "The topic to publish merge messages on"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint=$(opt_get "endpoint")
	topic=$(opt_get "topic")

	if ! inst_start _mergebot_run "$endpoint" "$topic"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "git" "inst" "ipc" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
