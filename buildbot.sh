#!/bin/bash

store_packages() {
	local context="$1"
	local builddir="$2"

	local package

	while read -r package; do
		if ! foundry_context_add_file "$context" "build" "$package"; then
			log_error "Could not store artifact $package in $context"
			return 1
		fi
	done < <(find "$builddir" -type f -name "*.deb")

	return 0
}

build() {
	local context="$1"
	local repository="$2"
	local branch="$3"
	local builddir="$4"

	local output
	local err

	err=0

	if ! output=$(git clone "$repository" "$builddir/sources" 2>&1) ||
	   ! output+=$(cd "$builddir/sources" 2>&1 && git checkout "$branch" 2>&1); then
		err=1
	fi

	if ! foundry_context_log "$context" "build" <<< "$output"; then
		log_error "Could not log to $context"
		return 1
	fi

	if (( err != 0 )); then
		return 1
	fi

	if ! output=$(cd "$builddir/sources" && dpkg-buildpackage --no-sign 2>&1); then
		err=1
	fi

	if ! foundry_context_log "$context" "build" <<< "$output"; then
		log_error "Could not log to $context"
		return 1
	fi

	if (( err != 0 )); then
		return 1
	fi

	if ! store_packages "$context" "$builddir"; then
		log_error "Could not store packages for $context"
		return 1
	fi

	return 0
}

send_build_notification() {
	local endpoint="$1"
	local topic="$2"
	local context="$3"
	local repository="$4"
	local branch="$5"
	local ref="$6"
	local result="$7"

	local buildmsg
	local artifacts

	artifacts=()

	if ! buildmsg=$(foundry_msg_build_new "$context"    \
					      "$repository" \
					      "$branch"     \
					      "$ref"        \
					      "$result"     \
					      artifacts); then
		log_error "Could not make build message"
		return 1
	fi

	log_info "Sending build message to $topic"
	if ! ipc_endpoint_publish "$endpoint" "$topic" "$buildmsg"; then
		log_error "Could not publish message on $endpoint to $topic"
		return 1
	fi

	return 0
}

handle_commit_message() {
	local endpoint="$1"
	local publish_to="$2"
	local commit="$3"

	local buildable_branches
	local repository
	local branch
	local ref
	local context_name
	local context
	local builddir
	local -i result
	local -i err

	buildable_branches=(
		"master"
		"stable"
	)
	result=0
	err=0

	if ! branch=$(foundry_msg_commit_get_branch "$commit"); then
		log_warn "No branch in commit message"
		return 1
	fi

	if ! array_contains "$branch" "${buildable_branches[@]}"; then
		log_warn "Refusing to build from $branch branch"
		return 0
	fi

	if ! repository=$(foundry_msg_commit_get_repository "$commit"); then
		log_warn "No repository in commit message"
		return 1
	fi

	if ! ref=$(foundry_msg_commit_get_ref "$commit"); then
		log_warn "No ref in commit message"
		return 1
	fi

	context_name="${repository##*/}"

	if ! context=$(foundry_context_new "$context_name"); then
		log_error "Could not create a context for $context_name"
		return 1
	fi

	inst_set_status "Building $context"

	if ! builddir=$(mktemp -d); then
		log_error "Could not make temporary build directory"
		return 1
	fi

	log_info "Building $context in $builddir"
	if ! build "$context" "$repository" "$ref" "$builddir"; then
		result=1
	fi

	log_info "Finished build of $context with status $result"

	if ! send_build_notification "$endpoint" "$publish_to" "$context" \
	                             "$repository" "$branch" "$ref" "$result"; then
		err=1
	fi

	if ! rm -rf "$builddir"; then
		log_warn "Could not remove temporary build directory $builddir"
	fi

	return "$err"
}

dispatch_tasks() {
	local endpoint_name="$1"
	local watch="$2"
	local publish_to="$3"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open endpoint $endpoint_name"
		return 1
	fi

	if ! ipc_endpoint_subscribe "$endpoint" "$watch"; then
		log_error "Could not subscribe to $watch"
		return 1
	fi

	while inst_running; do
		local msg
		local data
		local msgtype

		inst_set_status "Awaiting commit messages"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping malformed message"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$data") ||
		   [[ "$msgtype" != "commit" ]]; then
			log_warn "Dropping message with unexpected type"
			continue
		fi

		inst_set_status "Handling commit message"

		handle_commit_message "$endpoint" "$publish_to" "$data"
	done

	return 0
}

main() {
	local endpoint
	local watch
	local publish_to

	opt_add_arg "e" "endpoint"   "v" "pub/buildbot" "The IPC endpoint to listen on"
	opt_add_arg "w" "watch"      "v" "commits"      "The topic to watch for commit messages"
	opt_add_arg "p" "publish-to" "v" "builds"       "The topic to publish builds under"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint=$(opt_get "endpoint")
	watch=$(opt_get "watch")
	publish_to=$(opt_get "publish-to")

	if ! inst_start dispatch_tasks "$endpoint" "$watch" "$publish_to"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "ipc" "foundry/msg" "foundry/context"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
