#!/bin/bash

__init() {
	if ! include "json" "foundry/file"; then
		return 1
	fi

	return 0
}

foundry_directory_new() {
	local path="$1"

	local -a files
	local -a directories
	local entry
	local files_json
	local directories_json

	while read -r entry; do
		local file_obj

		if ! file_obj=$(foundry_file_new "$entry"); then
			return 1
		fi

		files+=("$file_obj")
	done < <(find "$path" -mindepth 1 -maxdepth 1 -type f)

	while read -r entry; do
		local dir_obj

		if ! dir_obj=$(foundry_directory_new "$entry"); then
			return 1
		fi

		directories+=("$dir_obj")
	done < <(find "$path" -mindepth 1 -maxdepth 1 -type d)

	files_json=$(json_array "${files[@]}")
	directories_json=$(json_array "${directories[@]}")

	json_object "name"        "s:${path##*/}"       \
	            "files"       "$files_json"       \
	            "directories" "$directories_json"
	return "$?"
}

foundry_directory_get_name() {
	local directory="$1"

	jq -r -e ".name" <<< "$directory"
}

foundry_directory_foreach_file() {
	local directory="$1"
	local userfunc="$2"
	local userdata=("${@:3}")

	local -i num_files
	local -i idx

	if ! num_files=$(jq -r -e '.files | length' <<< "$directory"); then
		return 1
	fi

	for (( idx = 0; idx < num_files; idx++ )); do
		local file
		local -i ret_val

		if ! file=$(jq -r -e ".files[$idx]" <<< "$directory"); then
			return 2
		fi

		"$userfunc" "$file" "${userdata[@]}"
		ret_val="$?"

		if (( ret_val != 0 )); then
			return "$ret_val"
		fi
	done

	return 0
}

foundry_directory_foreach_directory() {
	local directory="$1"
	local userfunc="$2"
	local userdata=("${@:3}")

	local -i num_directories
	local -i idx

	if ! num_directories=$(jq -r -e '.directories | length' <<< "$directory"); then
		return 1
	fi

	for (( idx = 0; idx < num_directories; idx++ )); do
		local child
		local -i ret_val

		if ! child=$(jq -r -e ".directories[$idx]" <<< "$directory"); then
			return 2
		fi

		"$userfunc" "$child" "${userdata[@]}"
		ret_val="$?"

		if (( ret_val != 0 )); then
			return "$ret_val"
		fi
	done

	return 0
}

_foundry_directory_print_file() {
	local file="$1"
	local prefix="$2"

	local name

	if ! name=$(foundry_file_get_name "$file"); then
		return 1
	fi

	if [[ -n "$prefix" ]]; then
		printf '%s/' "$prefix"
	fi

	printf '%s\n' "$name"
	return "$?"
}

foundry_directory_listing() {
	local directory="$1"
	local prefix="$2"

	local file
	local name
	local new_prefix

	if ! name=$(foundry_directory_get_name "$directory"); then
		return 1
	fi

	if [[ -n "$prefix" ]]; then
		new_prefix="$prefix/$name"
	else
		new_prefix="$name"
	fi

	if ! foundry_directory_foreach_file "$directory" \
	                                    _foundry_directory_print_file "$new_prefix"; then
		return 1
	fi

	if ! foundry_directory_foreach_directory "$directory" \
	                                         foundry_directory_listing "$new_prefix"; then
		return 1
	fi
	return 0
}
