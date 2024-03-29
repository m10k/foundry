#!/bin/bash

# slackbot.sh - Slack notification bot for foundry
# Copyright (C) 2022-2023 Matthias Kruk
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

make_commit_announcement() {
	local repository="$1"
	local branch="$2"
	local ref="$3"

	echo "*Commit* detected"
	echo '```'
	echo "Repository: $repository"
	echo "Branch:     $branch"
	echo "Ref:        $ref"
	echo '```'

	return 0
}

make_build_announcement() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local ref="$4"

	local artifacts

	if ! artifacts=$(foundry_context_get_files "$context"); then
		artifacts="(could not list artifacts)"
	elif [[ -z "$artifacts" ]]; then
		artifacts="(no artifacts)"
	fi

	echo "*Build* detected"
	echo '```'
	echo "Context:    $context"
	echo "Repository: $repository"
	echo "Branch:     $branch"
	echo "Ref:        $ref"
	echo '```'
	echo "Artifacts:"
	echo '```'
	echo "$artifacts"
	echo '```'

	return 0
}

make_sign_announcement() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local ref="$4"
	local key="$5"

	local artifacts

	if ! artifacts=$(foundry_context_get_files "$context" "signed"); then
		artifacts="(could not get artifacts)"
	elif [[ -z "$artifacts" ]]; then
		artifacts="(no artifacts)"
	fi

	echo "*Sign* detected"
	echo '```'
	echo "Context:    $context"
	echo "Repository: $repository"
	echo "Branch:     $branch"
	echo "Ref:        $ref"
	echo "GPG key:    $key"
	echo '```'
	echo "Artifacts:"
	echo '```'
	echo "$artifacts"
	echo '```'

	return 0
}

make_dist_announcement() {
	local repository="$1"
	local branch="$2"
	local ref="$3"
	local distribution="$4"
	local artifacts="$5"

	if [[ -z "$artifacts" ]]; then
		artifacts="(no artifacts)"
	fi

	echo "*dist* detected"
	echo '```'
	echo "Repository:   $repository"
	echo "Branch:       $branch"
	echo "Ref:          $ref"
	echo "Distribution: $distribution"
	echo '```'

	echo "Artifacts:"
	echo '```'
	echo "$artifacts"
	echo '```'

	return 0
}

handle_commit_message() {
	local commit_msg="$1"
	local channel="$2"
	local token="$3"

	local repository
	local branch
	local ref
	local msg

	if ! repository=$(foundry_msg_commit_get_repository "$commit_msg"); then
		log_warn "Dropping commit message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_commit_get_branch "$commit_msg"); then
		log_warn "Dropping commit message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_commit_get_ref "$commit_msg"); then
		log_warn "Dropping commit message without ref"
		return 1
	fi

	msg=$(make_commit_announcement "$repository" "$branch" "$ref")

	if ! slack_chat_post_message "$token" "$channel" "$msg"; then
		log_error "Could not send message to slack"
		return 1
	fi

	return 0
}

handle_build_message() {
	local build_msg="$1"
	local channel="$2"
	local token="$3"

	local context
	local repository
	local branch
	local ref
	local msg

	if ! context=$(foundry_msg_build_get_context "$build_msg"); then
		log_warn "Dropping build message without context"
		return 1
	fi

	if ! repository=$(foundry_msg_build_get_repository "$build_msg"); then
		log_warn "Dropping build message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_build_get_branch "$build_msg"); then
		log_warn "Dropping build message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_build_get_ref "$build_msg"); then
		log_warn "Dropping build message without ref"
		return 1
	fi

	msg=$(make_build_announcement "$context" "$repository" "$branch" "$ref")

	if ! slack_chat_post_message "$token" "$channel" "$msg"; then
		log_error "Could not send message to slack"
		return 1
	fi

	return 0
}

handle_sign_message() {
	local sign_msg="$1"
	local channel="$2"
	local token="$3"

	local context
	local repository
	local branch
	local ref
	local key
	local msg

	if ! context=$(foundry_msg_sign_get_context "$sign_msg"); then
		log_warn "Dropping sign message without context"
		return 1
	fi

	if ! repository=$(foundry_msg_sign_get_repository "$sign_msg"); then
		log_warn "Dropping sign message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_sign_get_branch "$sign_msg"); then
		log_warn "Dropping sign message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_sign_get_ref "$sign_msg"); then
		log_warn "Dropping sign message without ref"
		return 1
	fi

	if ! key=$(foundry_msg_sign_get_key "$sign_msg"); then
		log_warn "Dropping sign message without key"
		return 1
	fi

	msg=$(make_sign_announcement "$context" "$repository" "$branch" "$ref" "$key")

	if ! slack_chat_post_message "$token" "$channel" "$msg"; then
		log_error "Could not send message to slack"
		return 1
	fi

	return 0
}

handle_dist_message() {
	local dist_msg="$1"
	local channel="$2"
	local token="$3"

	local repository
	local branch
	local ref
	local distribution
	local artifacts
	local msg

	if ! repository=$(foundry_msg_dist_get_repository "$dist_msg"); then
		log_warn "Dropping dist message without repository"
		return 1
	fi

	if ! branch=$(foundry_msg_dist_get_branch "$dist_msg"); then
		log_warn "Dropping dist message without branch"
		return 1
	fi

	if ! ref=$(foundry_msg_dist_get_ref "$dist_msg"); then
		log_warn "Dropping dist message without ref"
		return 1
	fi

	if ! distribution=$(foundry_msg_dist_get_distribution "$dist_msg"); then
		log_warn "Dropping dist message without distribution"
		return 1
	fi

	if ! artifacts=$(foundry_msg_dist_get_artifacts "$dist_msg"); then
		log_warn "Dropping dist message without artifacts"
		return 1
	fi

	msg=$(make_dist_announcement "$repository" "$branch" "$ref" \
	                             "$distribution" "$artifacts")

	if ! slack_chat_post_message "$token" "$channel" "$msg"; then
		log_error "Could not send message to slack"
		return 1
	fi

	return 0
}

relay_message_to_slack() {
	local message="$1"
	local channel="$2"
	local token="$3"

	declare -A message_handlers
	local type

	message_handlers["commit"]=handle_commit_message
	message_handlers["build"]=handle_build_message
	message_handlers["sign"]=handle_sign_message
	message_handlers["dist"]=handle_dist_message

	if ! type=$(foundry_msg_get_type "$message"); then
		log_warn "Dropping invalid message"
		return 1
	fi

	if ! array_contains "$type" "${!message_handlers[@]}"; then
		log_warn "No handler for $type messages"
		return 1
	fi

	if ! "${message_handlers[$type]}" "$message" "$channel" "$token"; then
		return 1
	fi

	return 0
}

handle_messages() {
	local endpoint="$1"
	local channel="$2"
	local token="$3"

	while inst_running; do
		local msg
		local data

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping invalid message"
			continue
		fi

		relay_message_to_slack "$data" "$channel" "$token"
	done

	return 0
}

watch_topics() {
	local channel="$1"
	local token="$2"
	local topics=("${@:3}")

	local endpoint
	local -i err

	err=0

	if ! endpoint=$(ipc_endpoint_open); then
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "${topics[@]}"; then
		log_error "Could not subscribe to some topics"
		err=1
	else
		handle_messages "$endpoint" "$channel" "$token"
	fi

	if ! ipc_endpoint_close "$endpoint"; then
		log_error "Could not close endpoint $endpoint"
	fi

	return "$err"
}

_add_topic() {
	# local name="$1" # unused
	local value="$2"

	# `topics' is inherited from main()
	topics+=("$value")
	return 0
}

main() {
	local topics
	local token
	local channel
	local proto

	topics=()

	opt_add_arg "c" "channel" "v" ""     "Slack channel to send messages to"
	opt_add_arg "t" "token"   "v" ""     "Token for authentication with Slack"
	opt_add_arg "w" "watch"   "v" ""     "Topic to watch for messages (may be used more than once)" \
	            '' _add_topic
	opt_add_arg "P" "proto"   "v" "uipc" "The IPC flavor to use"                                    \
	            '^u?ipc$'

	if ! opt_parse "$@"; then
		return 1
	fi

	proto=$(opt_get "proto")
	if ! include "$proto"; then
		return 1
	fi

	if (( ${#topics[@]} == 0 )); then
		topics=(
			"commits"
			"builds"
			"signs"
			"dists"
		)
	fi

	if ! channel=$(conf_get "slack_channel"); then
		if ! channel=$(opt_get "channel") || [[ -z "$channel" ]]; then
			log_error "Need a slack channel"
			return 1
		elif ! conf_set "slack_channel" "$channel"; then
			log_warn "Could not save channel"
		fi
	fi

	if ! token=$(conf_get "slack_token"); then
		if ! token=$(opt_get "token") || [[ -z "$token" ]]; then
			log_error "Need a slack token"
			return 1
		elif ! conf_set "slack_token" "$token"; then
				log_warn "Could not save token"
		fi
	fi

	if ! inst_start watch_topics "$channel" "$token" "${topics[@]}"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "conf" "inst" "foundry/msg" "foundry/context" "slack"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
