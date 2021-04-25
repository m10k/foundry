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
	local output

	if ! output=$(dpkg-sig --verify "$package"); then
		log_error "Could not verify signature on $package"
		echo "$output" | log_highlight "dpkg-sig" | log_error

		return 1
	fi

	log_info "Good signature on $package"
	echo "$output" | log_highlight "dpkg-sig" | log_info

	return 0
}

process_new_package() {
	local package="$1"
	local repo="$2"
	local codename="$3"

	local failed

	failed=true

	log_info "New package: $package"

	if ! verify_package "$package"; then
		log_error "Invalid signature on package $package"
	elif ! repo_add_package "$repo" "$codename" "$package"; then
		log_error "Could not process $package"
	else
		log_info "$package successfully added to $repo:$codename"
		failed=false
	fi

	if "$failed"; then
		if ! mv "$package" "$repo/failed/."; then
			log_error "Could not move $package to $repo/failed/."
		fi
	else
		if ! rm "$package"; then
			log_error "Could not remove $package"
		fi
	fi

	return 0
}

watch_new_packages() {
	local queue="$1"
	local repo="$2"
	local codename="$3"

	while inst_running; do
		local package

		log_debug "Waiting on queue $queue"

	        if package=$(queue_get_file "$queue" "$repo/incoming"); then
			process_new_package "$package" "$repo" "$codename"
		fi
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
	local incoming
	local name
	local arch
	local gpgkey
	local desc

	opt_add_arg "n" "name"        "rv" ""       "The name of the repository"
	opt_add_arg "o" "output"      "rv" ""       "The path to the repository"
	opt_add_arg "c" "codename"    "v"  "stable" "The codename of the distribution (default: stable)"
	opt_add_arg "a" "arch"        "rv" ""       "Comma separated list of supported architectures"
	opt_add_arg "k" "gpgkey"      "rv" ""       "The GPG key used for signing"
	opt_add_arg "d" "description" "rv" ""       "Description of the repository"
	opt_add_arg "i" "input"       "rv" ""       "The queue to watch for incoming packages"

	if ! opt_parse "$@"; then
		return 1
	fi

	path=$(opt_get "output")
	codename=$(opt_get "codename")
	incoming=$(opt_get "input")
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

	inst_start watch_new_packages "$incoming" "$path" "$codename"

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
