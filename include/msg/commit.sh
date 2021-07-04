#!/bin/bash

__init() {
	if ! include "json"; then
		return 1
	fi

	return 0
}

foundry_msg_commit_new() {
	local repository="$1"
	local branch="$2"
	local commit="$3"

	local msg

	if ! msg=$(json_object "repository" "$repository" \
			       "commit"     "$commit"     \
			       "branch"     "$branch"); then
		return 1
	fi

	echo "$msg"
	return 0
}

_foundry_msg_commit_get_field() {
	local msg="$1"
	local field="$2"

	local value

	if ! value=$(echo "$msg" | jq -e -r ".$field"); then
		return 1
	fi

	echo "$value"
	return 0
}

foundry_msg_commit_get_repository() {
	local msg="$1"

	local repository

	if ! repository=$(_foundry_msg_commit_get_field "$msg" "repository"); then
		return 1
	fi

	echo "$repository"
	return 0
}

foundry_msg_commit_get_branch() {
	local msg="$1"

	local branch

	if ! branch=$(_foundry_msg_commit_get_field "$msg" "branch"); then
		return 1
	fi

	echo "$branch"
	return 0
}

foundry_msg_commit_get_commit() {
	local msg="$1"

	local commit

	if ! commit=$(_foundry_msg_commit_get_field "$msg" "commit"); then
		return 1
	fi

	echo "$commit"
	return 0
}
