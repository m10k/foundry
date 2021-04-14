#!/bin/bash

sem="distbot"

check_config() {
	local arg

	for arg in "$@"; do
		if ! conf_get "$arg" &> /dev/null; then
			log_error "$arg not configured"
			return 1
		fi
	done

	return 0
}

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

	if ! mkdir -p "$repo/conf" &>/dev/null; then
		log_error "Could not create $repo/conf"
		return 1
	fi

	config=$(make_repo_config "$domain" "$codename" "$arch" \
				  "$gpgkeyid" "$description")

	if ! echo "$config" > "$repo/conf/distributions"; then
		return 1
	fi

	return 0
}

stop() {
	if ! sem_post "$sem"; then
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

	return 0
}

process_new_packages() {
	local watchdir="$1"
	local repodir="$2"
	local codename="$3"

	local package

	while read -r package; do
		local failed

		failed=true

		log_info "New package: $package"

		if ! verify_package "$package"; then
			log_error "Invalid signature on package $package"
		elif ! repo_add_package "$repodir" "$codename" "$package"; then
			log_error "Could not process $package"
		else
			log_info "$package successfully added to $repodir:$codename"
			failed=false
		fi

		if "$failed"; then
			if ! mv "$package" "$repodir/failed/."; then
				log_error "Could not move $package to $dest"
			fi
		else
			if ! rm "$package"; then
				log_error "Could not remove $package"
			fi
		fi
	done < <(find "$watchdir" -type f -iname "*.deb")

	return 0
}

watch_new_packages() {
	local watchdir="$1"
	local repodir="$2"
	local codename="$3"

	local lock

	lock="$watchdir/lock"

	if ! trap stop TERM HUP INT EXIT QUIT; then
		return 1
	fi

	if ! sem_init "$sem" 0; then
		log_info "Looks like another instance is already running"
		return 1
	fi

	while ! sem_trywait "$sem"; do
		# Without the timeout, we'd wait forever even if we're told to stop
		if ! inotifywait -qq -t 15 "$watchdir/queue" &>/dev/null; then
			continue
		fi

		if mutex_lock "$lock"; then
			process_new_packages "$watchdir/queue" "$repodir" "$codename"
			mutex_unlock "$lock"
		else
			log_error "Could not acquire lock $lock"
		fi
	done

	if ! sem_destroy "$sem"; then
		log_error "Could not destroy semaphore $sem"
		return 1
	fi

	return 0
}

increase_verbosity() {
	local verbosity

	verbosity=$(log_get_verbosity)
	((verbosity++))
	log_set_verbosity "$verbosity"
	return 0
}

decrease_verbosity() {
	local verbosity

	verbosity=$(log_get_verbosity)
	((verbosity--))
	log_set_verbosity "$verbosity"
	return 0
}

main() {
	local repo_path
	local repo_codename
	local watchdir

	opt_add_arg "s" "stop"    "no" 0 "Stop a running instance"
	opt_add_arg "v" "verbose" "no" 0 "Be more verbose"         increase_verbosity
	opt_add_arg "w" "shush"   "no" 0 "Be less verbose"         decrease_verbosity

	if ! opt_parse "$@"; then
		return 1
	fi

	if (( $(opt_get "stop") > 0 )); then
		if ! stop; then
			return 1
		fi

		return 0
	fi

	if ! check_config "repo.path" "repo.domain" "repo.codename" \
	     "repo.architectures" "repo.gpgkey" "repo.description" "watchdir"; then
		return 1
	fi

	watchdir=$(conf_get "watchdir")
	repo_path=$(conf_get "repo.path")
	repo_codename=$(conf_get "repo.codename")

	if ! mkdir -p "$watchdir/queue" "$watchdir/failed"; then
		log_error "Could not create watchdir"
		return 1
	fi

	if ! [ -d "$repo_path" ]; then
		local repo_domain
		local repo_arch
		local repo_key
		local repo_desc

		repo_domain=$(conf_get "repo.domain")
		repo_arch=$(conf_get "repo.architectures")
		repo_key=$(conf_get "repo.gpgkey")
		repo_desc=$(conf_get "repo.description")

		log_info "Initializing repository $repo_domain:$repo_codename in $repo_path"

		if ! repo_init "$repo_path" "$repo_domain" "$repo_codename" \
		     "$repo_arch" "$repo_key" "$repo_desc"; then
			log_error "Could not initialize repository"
			return 1
		fi
	fi

	watch_new_packages "$watchdir" "$repo_path" "$repo_codename" \
			   </dev/null &>/dev/null &
	disown

	return 0
}

{
	if ! . toolbox.sh; then
		exit 1
	fi

	if ! include "log" "conf" "opt" "mutex" "sem"; then
		exit 1
	fi

	main "$@"
	exit "$?"
}
