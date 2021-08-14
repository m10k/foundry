#!/bin/bash

publish_results() {
	local endpoint="$1"
	local topic="$2"
	local key="$3"
	local context="$4"
	local result="$5"

	local sign

	if ! sign=$(foundry_msg_sign_new "$context" "$key"); then
		log_error "Could not make sign message"
		return 1
	fi

	if ! ipc_endpoint_publish "$endpoint" "$topic" "$sign"; then
		log_error "Could not publish sign message"
		return 1
	fi

	return 0
}

handle_sign_request() {
	local endpoint="$1"
	local topic="$2"
	local request="$3"
	local signer_key="$4"

	local context
	local artifact
	local signlog
	local result

	if ! context=$(foundry_msg_signrequest_get_context "$request"); then
		log_warn "No context in sign request. Dropping."
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
		fi
	done < <(foundry_context_get_files "$context" "build")

	if ! foundry_context_log "$context" "sign" <<< "$signlog"; then
		log_error "Could not log to context $context"
	fi

	if ! publish_results "$endpoint" "$topic" "$signer_key" \
	                     "$context" "$result"; then
		log_error "Could not publish results at $topic"
		return 1
	fi

	return 0
}

dispatch_tasks() {
	local endpoint_name="$1"
	local topic="$2"
	local signer_key="$3"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not open IPC endpoint $endpoint_name"
		return 1
	fi

	while inst_running; do
		local msg
		local data
		local msgtype

		inst_set_status "Awaiting sign requests"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! data=$(ipc_msg_get_data "$msg"); then
			log_warn "Received message without data. Dropping."
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$data") ||
		   [[ "$msgtype" != "signrequest" ]]; then
			log_warn "Received message with unexpected type. Dropping."
			continue
		fi

		inst_set_status "Sign request received"
		handle_sign_request "$endpoint" "$topic" "$data" "$signer_key"
	done

	return 0
}

main() {
	local endpoint
	local topic
	local key

	opt_add_arg "e" "endpoint" "v"  "pub/signbot" "The IPC endpoint to listen on"
	opt_add_arg "t" "topic"    "v"  "signs"       "The topic to publish signs under"
	opt_add_arg "k" "key"      "rv" ""            "Fingerprint of the key to sign with"

	if ! opt_parse "$@"; then
		return 1
	fi

	endpoint=$(opt_get "endpoint")
	topic=$(opt_get "topic")
	key=$(opt_get "key")

	if ! inst_start dispatch_tasks "$endpoint" "$topic" "$key"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "ipc" "foundry/context" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
