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
			log_warn "Dropping invalid message (no data)"
			continue
		fi

		if ! ctx=$(foundry_msg_merge_get_context "$fmsg"); then
			log_warn "Dropping invalid message (no context)"
			continue
		fi

		if [[ "$ctx" != "$context" ]]; then
			# message is about a different merge request
			continue
		fi

		if ! result=$(foundry_msg_merge_get_status "$fmsg"); then
			log_warn "Could not get result from merge message"
			return 1
		fi

		foundry_context_get_logs "$context" | log_highlight "Merge logs"
		return "$result"

	done

	return 1
}

test_mergebot() {
	local repository="$1"
	local srcbranch="$2"
	local dstbranch="$3"

	local endpoint
	local mergereq
	local project

	project="${repository##*/}"

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "merges"; then
		log_error "Could not subscribe to merges"
		return 1
	fi

	if ! context=$(foundry_context_new "$project"); then
		log_error "Could not make a new foundry context"
		return 1
	fi

	if ! mergereq=$(foundry_msg_mergerequest_new "$context" \
						     "$repository" \
						     "$srcbranch" \
						     "$dstbranch"); then
		log_error "Could not make mergerequest message"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/mergebot" "$mergereq"; then
		log_error "Could not send mergerequest"
		return 1
	fi

	if ! check_result "$endpoint" "$context"; then
		return 1
	fi

	return 0
}

main() {
	local repository
	local srcbranch
	local dstbranch

	opt_add_arg "r" "repository"  "rv" "" "Merge branches in this repository"
	opt_add_arg "s" "source"      "rv" "" "The branch to merge from"
	opt_add_arg "d" "destination" "rv" "" "The branch to merge into"

	if ! opt_parse "$@"; then
		return 1
	fi

	repository=$(opt_get "repository")
	srcbranch=$(opt_get "source")
	dstbranch=$(opt_get "destination")

	if ! test_mergebot "$repository" "$srcbranch" "$dstbranch"; then
		echo "Could not merge $repository [$srcbranch -> $dstbranch]"
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
