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
		local fmsgtype
		local ctx
		local result

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		ipc_msg_dump "$msg"

		if ! fmsg=$(ipc_msg_get_data "$msg"); then
			log_warn "Can't get data from message. Dropping."
			continue
		fi

		log_highlight "data" <<< "$fmsg" | log_debug

		if ! fmsgtype=$(foundry_msg_get_type "$fmsg"); then
			log_warn "Can't determine message type. Dropping."
			continue
		fi

		if [[ "$fmsgtype" != "build" ]]; then
			log_warn "Unexpected message type. Dropping."
			continue
		fi

		if ! ctx=$(foundry_msg_build_get_context "$fmsg"); then
			log_warn "Dropping message without context"
			continue
		fi

		if [[ "$ctx" != "$context" ]]; then
			# These are not the builds you're looking for
			continue
		fi

		if ! result=$(foundry_msg_build_get_result "$fmsg"); then
			log_error "Could not get result from build message"
			return 1
		fi

		foundry_context_get_logs "$context" | log_highlight "Build logs"
		foundry_context_get_files "$context" | log_highlight "Build artifacts"

		return "$result"
	done

	return 1
}

build() {
	local repository="$1"
	local branch="$2"

	local endpoint
	local package
	local buildreq
	local context

	package="${repository##*/}"

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "builds"; then
		log_error "Could not subscribe to builds"
		return 1
	fi

	if ! context=$(foundry_context_new "$package"); then
		log_error "Could not make a new foundry context"
		return 1
	fi

	if ! buildreq=$(foundry_msg_buildrequest_new "$context"    \
						     "$repository" \
						     "$branch"); then
		log_error "Could not make buildrequest message"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/buildbot" "$buildreq"; then
		log_error "Could not send buildrequest message"
		return 1
	fi

	if ! check_result "$endpoint" "$context"; then
		log_error "Build failed"
		return 1
	fi

	return 0
}

main() {
	local repository
	local branch

	opt_add_arg "r" "repository" "rv" "" "The repository to build"
	opt_add_arg "b" "branch"     "rv" "" "The branch to build"

	if ! opt_parse "$@"; then
		return 1
	fi

	repository=$(opt_get "repository")
	branch=$(opt_get "branch")

	if ! build "$repository" "$branch"; then
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
