#!/bin/bash

emit_signrequest() {
	local endpoint="$1"
	local buildmsg="$2"

	local signrequest
	local artifacts
	local artifact
	local have_artifacts

	artifacts=()
	have_artifacts=false

	while read -r artifact; do
		artifacts+=("$artifact")
		have_artifacts=true
	done < <(foundry_msg_build_get_artifacts "$buildmsg")

	if ! "$have_artifacts"; then
		return 1
	fi

	if ! signrequest=$(foundry_msg_signrequest_new "$tid" "${artifacts[@]}"); then
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/signbot" "$signrequest"; then
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
	local tid

	local testrequest

	if ! repository=$(foundry_msg_commit_get_repository "$msg") ||
	   ! branch=$(foundry_msg_commit_get_branch "$msg") ||
	   ! commit=$(foundry_msg_commit_get_commit "$msg"); then
		return 1
	fi

	if ! tid=$( false ); then
		return 1
	fi

	if ! testrequest=$(foundry_msg_testrequest_new "$tid" \
						       "$repository" \
						       "$branch" \
						       "$commit"); then
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/testbot" "$testrequest"; then
		return 1
	fi

	return 0
}

emit_buildrequest() {
	local endpoint="$1"
	local commitmsg="$2"

	local repository
	local branch
	local commit
	local tid

	local buildrequest

	if ! repository=$(foundry_msg_commit_get_repository "$commitmsg") ||
	   ! branch=$(foundry_msg_commit_get_branch "$commitmsg") ||
	   ! commit=$(foundry_msg_commit_get_commit "$commitmsg"); then
		return 1
	fi

	if ! tid=$( false ); then
		return 1
	fi

	if ! buildrequest=$(foundry_msg_buildrequest_new "$tid" \
							 "$repository" \
							 "$branch" \
							 "$commit"); then
		return 1
	fi

	if ! ipc_endpoint_send "$endpoint" "pub/buildbot" "$buildrequest"; then
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
	local testmsg="$2"

	local mergerequest
	local tid
	local repository
	local srcbranch
	local dstbranch
	local result

	if ! result=$(foundry_msg_test_get_result "$testmsg"); then
		return 1
	fi

	if (( result != 0 )); then
		# Nothing to do
		return 0
	fi

	if ! tid=$(foundry_msg_test_get_tid "$testmsg") ||
	   ! repository=$(foundry_msg_test_get_repository "$testmsg") ||
	   ! srcbranch=$(foundry_msg_test_get_branch "$testmsg"); then
		return 1
	fi

	if [[ "$srcbranch" != "testing" ]]; then
		# We only make mergerequests from testing to stable
		return 0
	fi

	dstbranch="stable"

	if ! mergerequest=$(foundry_msg_mergerequest_new "$tid" \
							 "$repository" \
							 "$srcbranch" \
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

	local result

	if ! result=$(foundry_msg_build_get_result "$msg"); then
		return 1
	fi

	if (( result == 0 )); then
		if ! emit_signrequest "$msg"; then
			return 1
		fi
	fi

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
		"stable")
		        if ! emit_buildrequest "$endpoint" "$msg" \
			                       "$repository" "$branch"; then
				return 1
			fi
			;;

		"testing")
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

	local result

	if ! result=$(foundry_msg_test_get_result "$msg"); then
		return 1
	fi

	if (( result == 0 )); then
		if ! emit_mergerequest "$endpoint" "$msg"; then
			return 1
		fi
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

_handle_notification() {
	local endpoint="$1"
	local msg="$2"

	local fmsg
	local type

	fmsg=$(foundry_msg_from_ipc_msg "$msg")
	type="$?"

	case "$type" in
		"$__foundry_msg_type_build")
			_handle_build "$endpoint" "$fmsg"
			;;

		"$__foundry_msg_type_commit")
			_handle_commit "$endpoint" "$fmsg"
			;;

		"$__foundry_msg_type_test")
			_handle_test "$endpoint" "$fmsg"
			;;

		"$__foundry_msg_type_sign")
			_handle_sign "$endpoint" "$fmsg"
			;;

		255)
			log_warn "Invalid message received"
			return 1
			;;

		*)
			log_warn "Unexpected message type: $type"
			return 1
			;;
	esac

	return 0
}

_route_messages() {
	local endpoint

	local topics
	local topic

	topics=("commits"
		"tests"
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

	if ! include "log" "opt" "ipc" "inst" "foundry/msg"; then
		return 1
	fi

	main "$@"
	exit "$?"
}
