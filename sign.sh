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
		local artifact
		local ret

		ret=0

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! fmsg=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping invalid message (not a foundry message)"
			continue
		fi

		if ! ctx=$(foundry_msg_sign_get_context "$fmsg"); then
			log_warn "Dropping invalid message (no context in message)"
			continue
		fi

		if [[ "$ctx" != "$context" ]]; then
			# Unrelated
			continue
		fi

		while read -r artifact; do
			if [[ "$artifact" != *".deb" ]]; then
				continue
			fi

			if ! dpkg-sig --verify "$artifact"; then
				log_error "Invalid signature on $artifact"
				ret=1
			fi
		done < <(foundry_context_get_files "$context")

		return "$ret"
	done

	return 1
}

test_signbot() {
	local project="$1"
	local artifacts=("${@:2}")

	local signreq
	local endpoint
	local context
	local artifact

	if ! context=$(foundry_context_new "$project"); then
		log_error "Could not create context for $project"
		return 1
	fi

	log_info "Created context $context"

	for artifact in "${artifacts[@]}"; do
		log_info "Adding $artifact to context $context"
		if ! foundry_context_add_file "$context" "build" "$artifact"; then
			log_error "Could not add $artifact to context $context"
			return 1
		fi
	done

	if ! signreq=$(foundry_msg_signrequest_new "$context"); then
		log_error "Could not make sign request"
		return 1
	fi

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open IPC endpoint"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "signs"; then
		log_error "Could not subscribe to topic \"signs\""
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/signbot" "$signreq"; then
		log_error "Could not send sign request to pub/signbot"
		return 1
	fi

	if ! check_result "$endpoint" "$context"; then
		return 1
	fi

	return 0
}

_add_artifact() {
	local name="$1"
	local value="$2"

	if [[ "$name" == "artifact" ]]; then
		artifacts+=("$value")
	fi

	return 0
}

main() {
	local artifacts
	local project

	artifacts=()

	opt_add_arg "a" "artifact" "rv" "" "An artifact to be signed" "" _add_artifact
	opt_add_arg "p" "project"  "rv" "" "Artifact project name"

	if ! opt_parse "$@"; then
		return 1
	fi

	project=$(opt_get "project")

	log_info "Signing project $project"
	array_to_lines "${artifacts[@]}" | log_highlight "artifacts" | log_info

	if ! test_signbot "$project" "${artifacts[@]}"; then
		echo "Signing failed"
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "ipc" "array" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
