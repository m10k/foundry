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
	if ! output=$(git clone "$repository" -b "$branch" "$builddir/sources" 2>&1); then
		err=1
	fi

	if ! foundry_context_log "$context" "build" <<< "$output"; then
		log_error "Could not log to $context"
		return 1
	fi

	if (( err != 0 )); then
		return 1
	fi

	if ! output=$(cd "$builddir/sources" && make deb 2>&1); then
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
	local result="$6"

	local buildmsg

	if ! buildmsg=$(foundry_msg_build_new "$context" "$repository" \
					      "$branch" "$result"); then
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

handle_build_request() {
	local endpoint="$1"
	local topic="$2"
	local request="$3"

	local context
	local repository
	local branch
	local builddir
	local result
	local err

	if ! context=$(foundry_msg_buildrequest_get_context "$request"); then
		log_warn "No context in buildrequest. Dropping."
		return 1
	fi

	inst_set_status "Building $context"

	if ! repository=$(foundry_msg_buildrequest_get_repository "$request"); then
		log_warn "No repository in buildrequest. Dropping."
		return 1
	fi

	if ! branch=$(foundry_msg_buildrequest_get_branch "$request"); then
		log_warn "No branch in buildrequest. Dropping."
		return 1
	fi

	if ! builddir=$(mktemp -d); then
		log_error "Could not make temporary build directory"
		return 1
	fi

	log_info "Building $context in $builddir"
	if ! build "$context" "$repository" "$branch" "$builddir"; then
		result=1
	else
		result=0
	fi

	log_info "Finished build of $context with status $result"

	if ! send_build_notification "$endpoint" "$topic" "$context" \
	                             "$repository" "$branch" "$result"; then
		err=1
	else
		err=0
	fi

	if ! rm -rf "$builddir"; then
		log_warn "Could not remove temporary build directory $builddir"
	fi

	return "$err"
}

dispatch_tasks() {
	local endpoint_name="$1"
	local topic="$2"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open endpoint $endpoint_name"
		return 1
	fi

	while inst_running; do
		local msg
		local data
		local msgtype

		inst_set_status "Awaiting build requests"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping malformed message"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$data") ||
		   [[ "$msgtype" != "buildrequest" ]]; then
			log_warn "Dropping message with unexpected type"
			continue
		fi

		inst_set_status "Build request received"

		handle_build_request "$endpoint" "$topic" "$data"
	done

	return 0
}

main() {
	local endpoint
	local topic

	opt_add_arg "e" "endpoint" "v" "pub/buildbot" "The IPC endpoint to listen on"
	opt_add_arg "t" "topic"    "v" "builds"       "The topic to publish builds under"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint=$(opt_get "endpoint")
	topic=$(opt_get "topic")

	if ! inst_start dispatch_tasks "$endpoint" "$topic"; then
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
