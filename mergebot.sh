#!/bin/bash

merge() {
	local repository="$1"
	local sbranch="$2"
	local dbranch="$3"

	local clone
	local err

	if ! clone=$(mktemp -d); then
		log_error "Could not make temporary directory"
		return 1
	fi

	err=1

	if ! git_clone "$repository" "$clone"; then
		log_error "Could not clone $repository to $clone"

	elif ! git_merge "$repository" "$sbranch" "$dbranch"; then
		log_error "Could not merge $sbranch into $dbranch in $repository"

	elif ! git_push "$repository" "$dbranch"; then
		log_error "Could not push $dbranch of $repository to origin"

	else
		err=0
	fi

	if ! rm -rf "$clone"; then
		log_warn "Could not clean up temporary directory $clone"
	fi

	return "$err"
}

handle_merge_request() {
	local mmsg="$1"

	local repository
	local sbranch
	local dbranch

	if ! repository=$(foundry_msg_mergerequest_get_repository "$mmsg") ||
			! sbranch=$(foundry_msg_mergerequest_get_source "$mmsg") ||
			! dbranch=$(foundry_msg_mergerequest_get_destination "$mmsg"); then
		log_warn "Dropping malformed message"
		return 1
	fi

	if ! merge "$repository" "$sbranch" "$dbranch"; then
		return 1
	fi

	return 0
}

handle_message() {
	local message="$1"

	local mmsg

	if ! mmsg=$(ipc_msg_get_data "$message"); then
		log_warn "Dropping malformed message"
		return 1
	fi

	if ! handle_merge_request "$mmsg"; then
		return 1
	fi

	return 0
}

_mergebot_run() {
	local endpoint_name="$1"

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

		handle_message "$msg"
	done

	return 0
}

main() {
	opt_add_arg "e" "endpoint" "v" "pub/mergebot" "The endpoint to receive messages on"

	if ! opt_parse "$@"; then
		return 1
	fi

	if ! inst_start _mergebot_run "$endpoint"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "ipc" "foundry/msg/mergerequest"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
