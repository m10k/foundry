#!/bin/bash

topics=("commits")
endpoints=()
processes=()

monitor_endpoints() {
	local endpoints=("$@")

	while inst_running; do
		sleep 5
	done

	return 0
}

watch_endpoints() {
	local endpoints=("$@")

	local endpoint

	# This function starts the monitor that watches all endpoints in the
	# build system. Because this function is executed before the other
	# components of the build system are started, endpoints are likely not
	# to exist. Hence, we also make sure to create all endpoints here.

	for endpoint in "${endpoints[@]}"; do
		if ! ipc_endpoint_open "$endpoint" > /dev/null; then
			log_error "Could not open endpoint $endpoint"
			return 1
		fi
	done

	if ! monitor_endpoints "${endpoints[@]}" &; then
		return 1
	fi

	return 0
}

process_is_running() {
	local process="$1"

	return 0
}

process_start() {
	local process="$1"

	return 0
}

process_watchdog() {
	local processes=("$@")

	local process

	while inst_running; do
		for process in "${processes[@]}"; do
			if process_is_running "$process"; then
				continue
			fi

			if ! process_start "$process"; then
				log_error "Could not start $process"
			fi
		done

		sleep 5
	done

	return 0
}

watch_processes() {
	local processes=("$@")

	if ! process_watchdog "${processes[@]}" &; then
		return 1
	fi

	return 0
}

handle_message() {
	local endpoint="$1"
	local msg="$2"

	return 1
}

smelter_run() {
	local endpoint
	local topic

	if ! endpoint=$(ipc_endpoint_open "pub/foundry"); then
		log_error "Could not listen on pub/foundry"
		return 1
	fi

	for topic in "${topics[@]}"; do
		if ! ipc_endpoint_subscribe "$endpoint" "$topic"; then
			log_error "Could not subscribe to $topic"
			return 1
		fi
	done

	if ! watch_endpoints "${endpoints[@]}"; then
		log_error "Couldn't start endpoint monitor"
		return 1
	fi

	if ! watch_processes "${processes[@]}"; then
		log_error "Couldn't start process monitor"
		return 1
	fi

	while inst_running; do
		local msg

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		handle_message "$endpoint" "$msg"
	done

	return 0
}

main() {
	if ! opt_parse "$@"; then
		return 1
	fi

	if ! inst_singleton smelter_run; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "inst" "ipc" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
