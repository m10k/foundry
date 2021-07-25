#!/bin/bash

topics=("commits")
FOUNDRY_ROOT="/var/lib/foundry"

get_endpoint_names() {
	local config

	while read -r config; do
		conf_get "endpoint" "$config"
	done < <(conf_get_domains)

	return 0
}

get_process_names() {
	local config

	while read -r config; do
		echo "$config"
	done < <(conf_get_domains)

	return 0
}

get_topic_names() {
	local config

	while read -r config; do
		conf_get "topic" "$config"
	done < <(conf_get_domains)

	return 0
}

_endpoint_message_log() {
	local endpoint="$1"
	local msg="$2"
	local logfile="$3"

	if ! echo "$msg" >> "$logfile"; then
		return 1
	fi

	return 0
}

monitor_endpoints() {
	local endpoints=("$@")

	while inst_running; do
		local endpoint

		for endpoint in "${endpoints[@]}"; do
			local logfile

			logfile="$FOUNDRY_ROOT/endpoints/$endpoint/queue"
			logdir="${logfile%/*}"

			if ! mkdir -p "$logdir"; then
				continue
			fi

			if ! :> "$logfile"; then
				continue
			fi

			ipc_endpoint_foreach_message "$endpoint" _endpoint_message_log "$logfile"
		done

		sleep 5
	done

	return 0
}

watch_endpoints() {
	local endpoints
	local endpoint

	readarray -t endpoints < <(get_endpoint_names)

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

	monitor_endpoints "${endpoints[@]}" &
	return 0
}

process_is_running() {
	local process="$1"

	local command
	local proc

	if ! command=$(conf_get "command" "$process"); then
		return 1
	fi

	while read -r proc; do
		if [[ "$proc" == *" --name $process "* ]]; then
			return 0
		fi

		if [[ "$proc" == *" --name $process" ]]; then
			return 0
		fi
	done < <(inst_list "$command")

	return 1
}

process_start() {
	local process="$1"

	local command
	local args
       	local param

	args=("--name" "$process")
	command=""

	while read -r param; do
		local value

		if ! value=$(conf_get "$param" "$process"); then
			continue
		fi

		if [[ "$param" == "command" ]]; then
			command="$value"
		else
			args+=("--$param" "$value")
		fi
	done < <(conf_get_names "$process")

	log_highlight "cmd" <<< "$command ${args[*]}" | log_debug

	if [[ -z "$command" ]]; then
		log_error "No command in configuration for $process"
		return 1
	fi

	if ! "$command" "${args[@]}"; then
		log_error "$command returned an error"
		return 1
	fi

	return 0
}

process_watchdog() {
	local processes=("$@")

	local process

	log_info "Process watchdog ready."

	while inst_running; do
		for process in "${processes[@]}"; do
			if process_is_running "$process"; then
				continue
			fi

			log_info "Process $process is not running. Starting it."

			if ! process_start "$process"; then
				log_error "Could not start $process"
			fi
		done

		sleep 5
	done

	return 0
}

watch_processes() {
	local processes

	readarray -t processes < <(conf_get_domains)
	array_to_lines "${processes[@]}" |
		log_highlight "processes" |
		log_info

	process_watchdog "${processes[@]}" &

	return 0
}

handle_admin_message() {
	local endpoint="$1"
	local msg="$2"

	return 0
}

handle_message() {
	local endpoint="$1"
	local msg="$2"

	local fmsg
	local msgtype

	if ! fmsg=$(ipc_msg_get_data "$msg"); then
		return 1
	fi

	if ! msgtype=$(foundry_msg_get_type "$fmsg"); then
		return 1
	fi

	if [[ "$msgtype" != "admin" ]]; then
		log_warn "Ignoring unexpected message"
		return 1
	fi

	if ! handle_admin_message "$endpoint" "$fmsg"; then
		return 1
	fi

	return 0
}

foundry_run() {
	local endpoint
	local topic

	if ! endpoint=$(ipc_endpoint_open "pub/foundry"); then
		log_error "Could not listen on pub/foundry"
		return 1
	fi

	while read -r topic; do
		if ! ipc_endpoint_subscribe "$endpoint" "$topic"; then
			log_error "Could not subscribe to $topic"
			return 1
		fi
	done < <(get_topic_names)

	if ! watch_endpoints; then
		log_error "Couldn't start endpoint monitor"
		return 1
	fi

	if ! watch_processes; then
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

	if ! inst_singleton foundry_run; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "conf" "opt" "inst" "ipc" "foundry/msg"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
