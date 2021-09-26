#!/bin/bash

emit_signrequest() {
	local endpoint="$1"
	local context="$2"
	local artifacts=("${@:3}")

	local signrequest
	local dst

	dst="pub/signbot"

	if (( ${#artifacts[@]} == 0 )); then
		log_warn "Nothing to be signed for $context"
		return 1
	fi

	if ! signrequest=$(foundry_msg_signrequest_new "$context" "${artifacts[@]}"); then
		log_error "Could not make sign request for $context"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "$dst" "$signrequest"; then
		log_error "Could not send signrequest to $dst"
		return 1
	fi

	return 0
}

emit_buildrequest() {
	local endpoint="$1"
	local context="$2"
	local repository="$3"
	local branch="$4"

	local buildreq

	if ! buildreq=$(foundry_msg_buildrequest_new "$context"    \
						     "$repository" \
						     "$branch"); then
		log_error "Could not make build request"
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/buildbot" "$buildreq"; then
		return 1
	fi

	return 0
}

emit_testrequest() {
	local endpoint="$1"
	local commitmsg="$2"

	local repository
	local branch
	local commit
	local context
	local project

	local testrequest

	if ! repository=$(foundry_msg_commit_get_repository "$msg") ||
	   ! branch=$(foundry_msg_commit_get_branch "$msg") ||
	   ! commit=$(foundry_msg_commit_get_commit "$msg"); then
		return 1
	fi

	project="${repository##*/}"

	if ! context=$(foundry_context_new "$project"); then
		return 1
	fi

	log_debug "Created context $context for $project"

	if ! testrequest=$(foundry_msg_testrequest_new "$context"    \
						       "$repository" \
						       "$branch"     \
						       "$commit"); then
		log_error "Could not make test request"
		return 1
	fi

	log_debug "Sending test request $endpoint -> pub/testbot"

	if ! ipc_endpoint_send "$endpoint" "pub/testbot" "$testrequest"; then
		return 1
	fi

	return 0
}

emit_distrequest() {
	local endpoint="$1"
	local signmsg="$2"

	local tid
	local artifacts
	local distrequest

	if ! tid=$(foundry_msg_sign_get_tid "$signmsg"); then
		return 1
	fi

	readarray -t artifacts < <(foundry_msg_sign_get_artifacts "$signmsg")

	if (( ${#artifacts[@]} == 0 )); then
		return 1
	fi

	if ! distrequest=$(foundry_msg_distrequest "$tid" "${artifacts[@]}"); then
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/distbot" "$distrequest"; then
		return 1
	fi

	return 0
}

emit_mergerequest() {
	local endpoint="$1"
	local context="$2"
	local repository="$3"
	local srcbranch="$4"
	local dstbranch="$5"

	local mergerequest

	if ! mergerequest=$(foundry_msg_mergerequest_new "$context"    \
							 "$repository" \
							 "$srcbranch"  \
							 "$dstbranch"); then
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/mergebot" "$mergerequest"; then
		return 1
	fi

	return 0
}

_handle_build() {
	local endpoint="$1"
	local msg="$2"

	local context
	local artifacts
	local artifact
	local result

	artifacts=()

	if ! context=$(foundry_msg_build_get_context "$msg"); then
		log_warn "Dropping message without context"
		return 0
	fi

	if ! result=$(foundry_msg_build_get_result "$msg"); then
		log_warn "Dropping message without result"
		return 0
	fi

	if (( result != 0 )); then
		log_warn "Not emitting sign request for failed build $context"
		return 0
	fi

	while read -r artifact; do
		artifacts+=("$artifact")
	done < <(foundry_msg_build_get_artifacts "$msg")

	if ! emit_signrequest "$endpoint" "$context" "${artifacts[@]}"; then
		log_error "Could not emit sign request for $context"
		return 1
	fi

	log_info "Sign request for $context emitted."

	return 0
}

_handle_commit() {
	local endpoint="$1"
	local msg="$2"

	local repository
	local branch

	if ! repository=$(foundry_msg_commit_get_repository "$msg") ||
	   ! branch=$(foundry_msg_commit_get_branch "$msg"); then
		return 1
	fi

	case "$branch" in
		"testing")
			log_debug "Commit on \"testing\" branch -> sending test request"

			if ! emit_testrequest "$endpoint" "$msg" \
			                      "$repository" "$branch"; then
				return 1
			fi
			;;

		*)
			log_warn "Ignoring commit on $repository#$branch"
			return 1
			;;
	esac

	return 0
}

_handle_test() {
	local endpoint="$1"
	local msg="$2"

	local context
	local repository
	local result
	local branch

	if ! context=$(foundry_msg_test_get_context "$msg"); then
		log_warn "Dropping test message without context"
		return 1
	fi

	if ! repository=$(foundry_msg_test_get_repository "$msg"); then
		log_warn "Dropping test message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_test_get_branch "$msg"); then
		log_warn "Dropping test message for \"$repository\" without branch"
		return 1
	fi

	if [[ "$branch" != "testing" ]]; then
		log_info "Ignoring test result for \"$repository\", branch \"$branch\""
		return 0
	fi

	if ! result=$(foundry_msg_test_get_result "$msg"); then
		log_warn "Dropping test message for \"$repository\" without result"
		return 1
	fi

	if (( result != 0 )); then
		log_info "Ignoring test for \"$repository\" with result \"$result\""
		return 0
	fi

	log_info "Sending merge request for \"$repository\""
	if ! emit_mergerequest "$endpoint" "$context" "$repository" \
	                       "testing" "stable"; then
		return 1
	fi

	return 0
}

_handle_sign() {
	local endpoint="$1"
	local msg="$2"

	if ! emit_distrequest "$endpoint" "$msg"; then
		return 1
	fi

	return 0
}

_handle_merge() {
	local endpoint="$1"
	local msg="$2"

	local context
	local repository
	local branch
	local accepted_branches

	accepted_branches=(
		"master"
		"stable"
	)

	if ! context=$(foundry_msg_merge_get_context "$msg"); then
		log_warn "Dropping merge message without context"
		return 0
	fi

	if ! repository=$(foundry_msg_merge_get_repository "$msg"); then
		log_warn "Dropping merge message without repository (context $context)"
		return 0
	fi

	if ! branch=$(foundry_msg_merge_get_destination_branch "$msg"); then
		log_warn "Dropping merge message for $context@$repository without destination branch"
		return 0
	fi

	if ! array_contains "$branch" "${accepted_branches[@]}"; then
		log_info "Ignoring merge message for $context@$repository#$branch"
		return 0
	fi

	if ! emit_buildrequest "$endpoint" "$context" "$repository" "$branch"; then
		log_error "Could not send build request for $repository#$branch"
		return 1
	fi

	return 0
}

_handle_notification() {
	local endpoint="$1"
	local msg="$2"

	local fmsg
	local type
	declare -A handlers

	handlers["build"]=_handle_build
	handlers["commit"]=_handle_commit
	handlers["test"]=_handle_test
	handlers["sign"]=_handle_sign
	handlers["merge"]=_handle_merge

	if ! fmsg=$(ipc_msg_get_data "$msg"); then
		log_warn "Dropping message without data"
		return 1
	fi

	if ! type=$(foundry_msg_get_type "$fmsg"); then
		log_warn "Dropping message without type"
		return 1
	fi

	log_debug "Received $type message"

	if ! array_contains "$type" "${!handlers[@]}"; then
		log_warn "Unexpected message type: $type"
		return 1
	fi

	log_debug "Message is handled by ${handlers[$type]}"

	if ! "${handlers[$type]}" "$endpoint" "$fmsg"; then
		return 1
	fi

	return 0
}

_route_messages() {
	local endpoint

	local topics
	local topic

	topics=("commits"
		"tests"
		"merges"
		"builds"
		"signs")

	if ! endpoint=$(ipc_endpoint_open); then
		log_error "Could not open endpoint"
		return 1
	fi

	for topic in "${topics[@]}"; do
		if ! ipc_endpoint_subscribe "$endpoint" "$topic"; then
			log_error "Could not subscribe to $topic"
			return 1
		fi
	done

	while inst_running; do
		local msg

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		_handle_notification "$endpoint" "$msg"
	done

	return 0
}

main() {
	opt_add_arg "n" "name" "rv" "" "The name of this instance"

	if ! opt_parse "$@"; then
		return 1
	fi

	if ! inst_singleton _route_messages; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		return 1
	fi

	if ! include "log" "opt" "ipc" "inst" "foundry/msg" "foundry/context"; then
		return 1
	fi

	main "$@"
	exit "$?"
}
