#!/bin/bash

publish_results() {
	local endpoint="$1"
	local topic="$2"
	local key="$3"
	local context="$4"
	local repository="$5"
	local branch="$6"
	local ref="$7"

	local sign

	if ! sign=$(foundry_msg_sign_new "$context"    \
					 "$key"        \
					 "$repository" \
					 "$branch"     \
					 "$ref"); then
		log_error "Could not make sign message"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$sign"; then
		log_error "Could not publish sign message"
		return 1
	fi

	return 0
}

handle_build_message() {
	local endpoint="$1"
	local publish_to="$2"
	local buildmsg="$3"
	local signer_key="$4"

	local repository
	local branch
	local ref
	local build_context
	local context_name
	local context
	local artifact
	local signlog
	local result

	if ! result=$(foundry_msg_build_get_result "$buildmsg")         ||
	   ! repository=$(foundry_msg_build_get_repository "$buildmsg") ||
	   ! branch=$(foundry_msg_build_get_branch "$buildmsg")         ||
	   ! ref=$(foundry_msg_build_get_ref "$buildmsg")               ||
	   ! build_context=$(foundry_msg_build_get_context "$buildmsg"); then
		log_warn "Malformed build message. Dropping."
		return 1
	fi

	if ! is_digits "$result" ||
	   (( result != 0 )); then
		log_warn "Not signing $repository#$branch [$ref] (build result was $result)"
		return 1
	fi

	context_name="${repository##*/}"

	if ! context=$(foundry_context_new "$context_name"); then
		log_error "Could not make new context for $context_name"
		return 1
	fi

	inst_set_status "Signing $context"

	signlog=""
	result=0

	while read -r artifact; do
		if [[ "$artifact" != *".deb" ]]; then
			continue
		fi

		if ! signlog+=$(dpkg-sig --sign "builder" \
					 -k "$signer_key" \
					 "$artifact" 2>&1); then
			log_error "Could not sign $artifact with key $signer_key"
			result=1

		elif ! signlog+=$(foundry_context_add_file "$context" \
							   "signed"   \
							   "$artifact" 2>&1); then
			log_error "Could not add $artifact to context $context"
			result=1
		fi
	done < <(foundry_context_get_files "$build_context" "build")

	if ! foundry_context_log "$context" "sign" <<< "$signlog"; then
		log_error "Could not log to context $context"
		result=1
	fi

	if (( result == 0 )); then
		if ! publish_results "$endpoint" "$publish_to" \
		                     "$signer_key" "$context"  \
		                     "$repository" "$branch"   \
	                             "$ref"; then
			log_error "Could not publish results to $publish_to"
			result=1
		fi
	else
		if ! publish_results "$endpoint" "signbot_errors" \
		                     "$signer_key" "$context"     \
		                     "$repository" "$branch"      \
		                     "$ref"; then
			log_error "Could not send error to signbot_errors"
		fi
	fi

	return "$result"
}

dispatch_tasks() {
	local endpoint_name="$1"
	local watch="$2"
	local publish_to="$3"
	local signer_key="$4"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open IPC endpoint $endpoint_name"
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

		inst_set_status "Watching for build messages"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Received message without data. Dropping."
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$data") ||
		   [[ "$msgtype" != "build" ]]; then
			log_warn "Received message with unexpected type. Dropping."
			continue
		fi

		inst_set_status "Handling build message"
		handle_build_message "$endpoint" "$publish_to" "$data" "$signer_key"
	done

	return 0
}

main() {
	local endpoint
	local watch
	local publish_to
	local key

	opt_add_arg "e" "endpoint"   "v"  "pub/signbot" "The IPC endpoint to listen on"
	opt_add_arg "w" "watch"      "v"  "builds"      "The topic to watch for build messages"
	opt_add_arg "p" "publish-to" "v"  "signs"       "The topic to publish signs under"
	opt_add_arg "k" "key"        "rv" ""            "Fingerprint of the key to sign with"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint=$(opt_get "endpoint")
	watch=$(opt_get "watch")
	publish_to=$(opt_get "publish-to")
	key=$(opt_get "key")

	if ! inst_start dispatch_tasks "$endpoint" "$watch" "$publish_to" "$key"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "is" "log" "opt" "inst" "ipc" "foundry/context" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
