#!/bin/bash

# spinbot.sh - Foundry bot for RPM rebuilds
# Copyright (C) 2023 Cybertrust Japan Co., Ltd.
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

error() {
	local message="$1"

	# TODO: Send message to error channel
	log_error "$message"
}

uri_is_local() {
	local uri="$1"

	if [[ "${uri:0:1}" == "/" ]] || [[ "$uri" == "file:///"* ]]; then
		return 0
	fi

	return 1
}

file_is_valid() {
	local file="$1"
	local sourceref="$2"

	local checksum

	if ! checksum=$(foundry_sourceref_get_checksum "$sourceref"); then
		log_error "Could not get checksum from sourceref"
		return 1
	fi

	foundry_checksum_validate "$checksum" "$file"
	return "$?"
}

gather_srpms() {
	local sourceref="$1"
	local context="$2"
	local -n srpm_list="$3"

	local uri
	local local_uri
	local context_root
	local destination

	context_root=$(foundry_context_get_root)
	destination="$context_root/$context/files/srpms"

	if ! uri=$(foundry_sourceref_get_uri "$sourceref"); then
		log_error "Could not get URI from sourceref"
		return 1
	fi

	if ! mkdir -p "$destination"; then
		log_error "Could not create directory $destination"
		return 1
	fi

	if uri_is_local "$uri"; then
		uri="${uri#file://}"

		log_info "Copying $uri to $destination"

		if ! cp "$uri" "$destination/."; then
			log_error "Could not copy $uri to $destination"
			return 1
		fi
	else
		log_info "Downloading $uri to $destination"

		if ! curl --get --silent --location \
		     --output-dir "$destination"    \
		     --remote-name "$uri"; then
			log_error "Could not download $uri to $destination"
			return 1
		fi
	fi

	local_uri="$destination/${uri##*/}"

	if ! file_is_valid "$local_uri" "$sourceref"; then
		return 1
	fi

	srpm_list+=("$local_uri")

	return 0
}

build_in_context() {
	local context="$1"
	local srpms=("${@:2}")

	local context_root
	local mock_config
	local resultdir
	local logdir
	local -a args

	context_root=$(foundry_context_get_root)
	mock_config="$context_root/$context/mock.cfg"
	resultdir="$context_root/$context/files" # mock will create "results/mock" subdir
	logdir="$context_root/$context/logs"

	log_info "Executing: mock --root $mock_config --clean --scrub=all"
	if ! mock --root "$mock_config" --clean --scrub=all; then
		log_error "Could not clean up build root"
		return 1
	fi

	args=(
		--root "$mock_config"
		--chain
		--continue
		--localrepo "$resultdir"
		"${srpms[@]}"
	)

	if ! foundry_timestamp_now > "$context_root/$context/stats_start"; then
		log_error "Could not write start time to $context_root/$context/stats_start"
	fi

	log_info "Executing: mock ${args[*]} 1> $logdir/mock.stdout 2> $logdir/mock.stderr"
	if ! mock "${args[@]}"        \
	     1> "$logdir/mock.stdout" \
	     2> "$logdir/mock.stderr"; then
		return 1
	fi

	if ! foundry_timestamp_now > "$context_root/$context/stats_end"; then
		log_error "Could not write end time to $context_root/$context/stats_end"
	fi

	return 0
}

uri_to_nvr() {
	local uri="$1"

	local file
	local nvr

	file="${uri##*/}"
        nvr="${file%.*.*}"

	echo "$nvr"
}

context_collect_build() {
	local sourceref="$1"
	local context="$2"
	local -n ___builds="$3"

	local pkg_uri
	local pkg_nvr
	local result_dir
	local build

	log_info "___builds = $3"

	if ! pkg_uri=$(foundry_sourceref_get_uri "$sourceref"); then
		return 1
	fi

	pkg_nvr=$(uri_to_nvr "$pkg_uri")
	result_dir="$(foundry_context_get_root)/$context/files/results/mock/$pkg_nvr"

	log_info "Collecting build for package $pkg_nvr from $result_dir"

	if ! build=$(foundry_build_new "sourceref" "$sourceref" \
	                               "artifacts" "$result_dir"); then
		log_error "Could not get build from $result_dir"
		return 1
	fi

	___builds+=("$build")
	return 0
}

context_collect_builds() {
	local context="$1"
	local request="$2"
	local builds_ref="$3"

	log_info "Collecting builds in context $context (ref: $builds_ref)"

	# Generate one build result for each sourceref
	if ! foundry_buildrequest_foreach_sourceref "$request"            \
	                                            context_collect_build \
	                                            "$context"            \
	                                            "$builds_ref"; then
		return 1
	fi

	return 0
}

context_collect_stats() {
	local context="$1"

	local context_dir
	local start_time
	local end_time

	context_dir="$(foundry_context_get_root)/$context"
	if ! start_time=$(< "$context_dir/stats_start"); then
		start_time=$(foundry_timestamp_from_unix 0)
	fi

	if ! end_time=$(< "$context_dir/stats_end"); then
		end_time=$(foundry_timestamp_from_unix 0)
	fi

	foundry_stats_new "start_time" "$start_time" \
	                  "end_time"   "$end_time"   \
	                  "memory"     0 \
	                  "disk"       0
	return "$?"
}

context_get_distribution() {
	local context="$1"

	local context_root

	if ! context_root=$(foundry_context_get_root); then
		return 1
	fi

	cat "$context_root/$context/distribution"
	return "$?"
}

send_build_result() {
	local endpoint="$1"
	local context="$2"
	local request="$3"
	local -i status="$4"

	local -A topics
	local -a builds
	local stats
	local message
	local architecture
	local distribution

	if ! architecture=$(get_native_arch); then
		return 1
	fi

	if ! distribution=$(context_get_distribution "$context"); then
		log_error "Could not get distribution of context $context"
		return 1
	fi

	topics["$status"]=$(opt_get "failure-topic")
	topics["0"]=$(opt_get "output-topic")

	log_info "Build finished with status $status"

	builds=()
	stats=$(context_collect_stats "$context")
	context_collect_builds "$context" "$request" builds

	message=$(foundry_msgv2_new "foundry.msg.build.result"     \
	                            "status"  "$status"            \
	                            "context" "$context"           \
	                            "builds"  builds               \
	                            "host"    "$HOSTNAME"          \
	                            "process" "spinbot.$$"         \
	                            "stats"   "$stats"             \
	                            "architecture" "$architecture" \
	                            "distribution" "$distribution")

	if ! ipc_endpoint_publish "$endpoint" "${topics[$status]}" "$message"; then
		log_error "Could not publish build result message to ${topics[$status]}"
		return 1
	fi

	return 0
}

get_native_arch() {
	local machine
	local -A arch_map
	local native_arch

	if ! machine=$(uname -m); then
		return 1
	fi

	arch_map=(
		["i386"]="i386"
		["i486"]="i386"
		["i586"]="i386"
		["i686"]="i386"
		["x86_64"]="amd64"
		["aarch64"]="arm64"
		["riscv64"]="riscv64"
	)

	native_arch="${arch_map[$machine]}"

	if [[ -z "$native_arch" ]]; then
		log_error "Architecture not supported"
		return 1
	fi

	echo "$native_arch"
	return 0
}

can_build_natively() {
	local requested_archs=("$@")

	local my_arch

	if ! my_arch=$(get_native_arch); then
		return 1
	fi

	if ! array_contains "$my_arch" "${requested_archs[@]}"; then
		return 1
	fi

	return 0
}

prepare_mock_env() {
	local request="$1"
	local context="$2"

	local distribution
	local context_root
	local config_src
	local config_dst

	context_root=$(foundry_context_get_root)
	distribution=$(foundry_buildrequest_get_distribution "$request")

	config_src="/var/lib/foundry/config/mock/$distribution.cfg"
	config_dst="$context_root/$context/mock.cfg"

	if ! echo "$distribution" > "$context_root/$context/distribution"; then
		log_error "Could not write to $context_root/$context/distribution"
		return 2
	fi

	log_info "Using mock root $config_src"
	if ! ln -s "$config_src" "$config_dst"; then
		log_error "Could not link from $config_dst to $config_src"
		return 1
	fi

	return 0
}

handle_build_request() {
	local endpoint="$1"
	local request="$2"

	local context
	local -a srpms
	local -i build_status
	local -a architectures
	local distribution

	if ! readarray -t architectures < <(foundry_buildrequest_get_architectures "$request"); then
		error "Could not get architectures from build request"
		return 1
	fi

	log_info "Checking if any of { ${architectures[*]} } can be built natively on this machine"
	if ! can_build_natively "${architectures[@]}"; then
		log_info "None of the requested architectures can be built on this machine. Ignoring request."
		return 0
	fi

	log_info "Creating context..."
	if ! context=$(foundry_context_new "$HOSTNAME.spinbot"); then
		log_error "Could not create context"
		return 1
	fi

	srpms=()
	build_status=0

	log_info "Gathering SRPMs"
	foundry_buildrequest_foreach_sourceref "$request" gather_srpms "$context" srpms

	inst_set_status "Preparing: ${srpms[*]}"
	log_info "Preparing mock environment"
	if ! prepare_mock_env "$request" "$context"; then
		log_error "Could not prepare mock environment"
		return 1
	fi

	inst_set_status "Building: ${srpms[*]}"
	log_info "Starting build"
	if ! build_in_context "$context" "${srpms[@]}"; then
		build_status=1
	fi

	inst_set_status "Finalizing: ${srpms[*]}"
	log_info "Propagating build result"
	send_build_result "$endpoint" "$context" "$request" "$build_status"

	return 0
}

handle_message() {
	local endpoint="$1"
	local message="$2"

	local type
	local build_request

	inst_set_status "Handling request"
	type=$(foundry_msgv2_get_type "$message")

	if [[ "$type" != "foundry.msg.build.request" ]]; then
		log_warn "Dropping message of type $type"
		return 0
	fi

	build_request=$(foundry_msgv2_get_buildrequest "$message")
	handle_build_request "$endpoint" "$build_request"
	return "$?"
}

run_spinbot() {
	local team="$1"
	local input_topic="$2"

	local endpoint
	local endpoint_name

	if [[ -n "$team" ]]; then
		endpoint_name="foundry.spinbot.$team"
	else
		endpoint_name=""
	fi

	if ! endpoint=$(foundry_common_make_endpoint "$endpoint_name" "$input_topic"); then
		return 1
	fi

	while inst_running; do
		local msg
		local data

		inst_set_status "Waiting for requests"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		data=$(ipc_msg_get_data "$msg")
		handle_message "$endpoint" "$data"
	done

	return 0
}

main() {
	local input_topic
	local protocol
	local team

	opt_add_arg "I" "input-topic"   "v" "foundry.build.requests"  \
	            "The topic to listen for build requests on"
	opt_add_arg "O" "output-topic"  "v" "foundry.build.succeeded" \
	            "The topic to announce successful builds on"
	opt_add_arg "F" "failure-topic" "v" "foundry.build.failed"    \
	            "The topic to announce failed builds on"
	opt_add_arg "E" "error-topic"   "v" "foundry.errors"          \
	            "The topic to send error messages to"
	opt_add_arg "p" "protocol"      "v" "uipc"                    \
	            "The IPC flavor to use"
	opt_add_arg "t" "team"          "v" ""                        \
	            "Join team for load distribution"

	if ! opt_parse "$@"; then
		return 1
	fi

	input_topic=$(opt_get "input-topic")
	protocol=$(opt_get "protocol")
	team=$(opt_get "team")

	if ! include "$protocol"; then
		return 1
	fi

	if ! inst_start run_spinbot "$team" "$input_topic"; then
		return 1
	fi

	return 0
}

{
	if ! . toolbox.sh ||
	   ! include "log" "opt" "inst"     \
	             "foundry/common"       \
	             "foundry/context"      \
	             "foundry/msgv2"        \
	             "foundry/sourceref"    \
	             "foundry/checksum"     \
	             "foundry/stats"        \
	             "foundry/timestamp"    \
	             "foundry/buildrequest" \
	             "foundry/build"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
