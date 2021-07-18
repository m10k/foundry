#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_buildrequest_msgtype="buildrequest"

	return 0
}

foundry_msg_buildrequest_new() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local commit="$4"

	local json
	local msg

	if ! json=$(json_object "context"    "$context"    \
				"repository" "$repository" \
				"branch"     "$branch"     \
				"commit"     "$commit"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_buildrequest_msgtype" "$json"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_buildrequest_get_context() {
	local msg="$1"

	local context

	if ! context=$(foundry_msg_get_data_field "$msg" "context"); then
		return 1
	fi

	echo "$context"
	return 0
}

foundry_msg_buildrequest_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_buildrequest_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_buildrequest_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(foundry_msg_get_data_field "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}
