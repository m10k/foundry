#!/bin/bash

make_repo_config() {
    local domain="$1"
    local codename="$2"
    local architectures="$3"
    local gpgkeyid="$4"
    local description="$5"

    echo "Origin: $domain"
    echo "Label: $domain"
    echo "Codename: $codename"
    echo "Architectures: $architectures"
    echo "Components: main"
    echo "Description: $description"
    echo "SignWith: $gpgkeyid"

    return 0
}

repo_init() {
	local repo="$1"
	local domain="$2"
	local codename="$3"
	local arch="$4"
	local gpgkeyid="$5"
	local description="$6"

	local config

	if ! mkdir -p "$repo/conf" "$repo/incoming" "$repo/failed" &>/dev/null; then
		log_error "Could not create directory structure in $repo"
		return 1
	fi

	config=$(make_repo_config "$domain" "$codename" "$arch" \
				  "$gpgkeyid" "$description")

	if ! echo "$config" > "$repo/conf/distributions"; then
		return 1
	fi

	return 0
}

repo_add_package() {
	local repository="$1"
	local codename="$2"
	local package="$3"

	log_info "Adding $package to $repository:$codename"

	if ! reprepro -b "$repository" includedeb \
	              "$codename" "$package"; then
		return 1
	fi

	return 0
}

verify_package() {
	local package="$1"

	log_info "Verifying signature on $package"
	if ! dpkg-sig --verify "$package" | log_info "dpkg-sig --verify \"$package\""; then
		log_error "Could not verify signature on $package"

		return 1
	fi

	log_info "Good signature on $package"

	return 0
}

process_new_package() {
	local context="$1"
	local package="$2"
	local repo="$3"
	local codename="$4"

	local failed
	local logoutput

	failed=true

	log_info "[#$context] New package: $package"

	if ! logoutput=$(verify_package "$package" 2>&1); then
		log_error "[#$context] Invalid signature on package $package"
	elif ! logoutput+=$(repo_add_package "$repo" "$codename" "$package" 2>&1); then
		log_error "[#$context] Could not process $package"
	else
		log_info "[#$context] $package successfully added to $repo:$codename"
		failed=false
	fi

	if "$failed"; then
		if ! log_output+=$(mv "$package" "$repo/failed/." 2>&1); then
			log_error "[#$context] Could not move $package to $repo/failed/."
		fi
	else
		if ! log_output+=$(rm "$package" 2>&1); then
			log_error "[#$context] Could not remove $package"
		fi
	fi

	if ! foundry_context_log "$context" "dist" <<< "$logoutput"; then
		log_error "Could not log to dist log of $context"
		return 1
	fi

	return 0
}

process_dist_request() {
	local repo="$1"
	local codename="$2"
	local distreq="$3"
	local endpoint="$4"
	local topic="$5"

	local artifacts
	local artifact
	local context

	if ! context=$(foundry_msg_distrequest_get_context "$distreq"); then
		log_warn "Dropping dist request without context"
		return 1
	fi

	readarray -t artifacts < <(foundry_context_get_files "$context")

	for artifact in "${artifacts[@]}"; do
		process_new_package "$context" "$artifact" "$repo" "$codename"
	done

	return 0
}

watch_new_packages() {
	local endpoint_name="$1"
	local topic="$2"
	local repo="$3"
	local codename="$4"

	local endpoint

	if ! endpoint=$(ipc_endpoint_open "$endpoint_name"); then
		log_error "Could not listen on IPC endpoint $endpoint_name"
		return 1
	fi

	while inst_running; do
		local msg
		local distreq
		local msgtype

		inst_set_status "Waiting for dist requests"

		if ! msg=$(ipc_endpoint_recv "$endpoint" 5); then
			continue
		fi

		if ! distreq=$(ipc_msg_get_data "$msg"); then
			log_warn "Dropping message without data"
			continue
		fi

		if ! msgtype=$(foundry_msg_get_type "$distreq"); then
			log_warn "Dropping message without type"
			continue
		fi

		if [[ "$msgtype" != "distrequest" ]]; then
			log_warn "Dropping message with unexpected type $msgtype"
			continue
		fi

		process_dist_request "$repo" "$codename" "$distreq" \
				     "$endpoint" "$topic"
	done

	return 0
}

looks_like_a_repository() {
	local path="$1"

	if ! [ -d "$path" ]; then
		return 1
	fi

	if ! [ -d "$path/incoming" ]; then
		return 1
	fi

	return 0
}

main() {
	local path
	local codename
	local endpoint
	local topic
	local name
	local arch
	local gpgkey
	local desc

	opt_add_arg "e" "endpoint"    "v"  "pub/distbot" "The IPC endpoint to listen on"
	opt_add_arg "t" "topic"       "v"  "dists"       "The topic to publish messages at"
	opt_add_arg "n" "name"        "rv" ""            "The name of the repository"
	opt_add_arg "o" "output"      "rv" ""            "The path to the repository"
	opt_add_arg "c" "codename"    "v"  "stable"      \
		    "The codename of the distribution (default: stable)"
	opt_add_arg "a" "arch"        "rv" ""            \
		    "Comma separated list of supported architectures"
	opt_add_arg "k" "gpgkey"      "rv" ""            \
		    "The GPG key used for signing"
	opt_add_arg "d" "description" "rv" ""            \
		    "Description of the repository"

	if ! opt_parse "$@"; then
		return 1
	fi

	path=$(opt_get "output")
	codename=$(opt_get "codename")
	endpoint=$(opt_get "endpoint")
	topic=$(opt_get "topic")
	name=$(opt_get "name")
	arch=$(opt_get "arch")
	gpgkey=$(opt_get "gpgkey")
	desc=$(opt_get "description")

	if ! looks_like_a_repository "$path"; then
		# Create new repository
		log_info "Initializing repository $name:$codename in $path"

		if ! repo_init "$path" "$name" "$codename" "$arch" "$gpgkey" "$desc"; then
			log_error "Could not initialize repository"
			return 1
		fi
	fi

	inst_start watch_new_packages "$endpoint" "$topic" "$path" "$codename"

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "opt" "queue" "inst"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
