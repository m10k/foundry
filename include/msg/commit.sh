#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	declare -gxr __foundry_msg_commit_msgtype="commit"

	return 0
}

foundry_msg_commit_new() {
	local repository="$1"
	local branch="$2"
	local commit="$3"

	local data
	local msg

	if ! data=$(json_object "repository" "$repository" \
				"commit"     "$commit"     \
				"branch"     "$branch"); then
		return 1
	fi

	if ! msg=$(foundry_msg_new "$__foundry_msg_commit_msgtype" "$data"); then
		return 1
	fi

	echo "$msg"
	return 0
}

foundry_msg_commit_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(foundry_msg_get_data_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_commit_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(foundry_msg_get_data_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_commit_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(foundry_msg_get_data_field "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}
