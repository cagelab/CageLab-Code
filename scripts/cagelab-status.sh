#!/usr/bin/env zsh
# a script to check whether the local cogmoteGO status API reports the service
# as running.

readonly status_url="http://localhost:9012/api/status"

if ! command -v jq >/dev/null 2>&1; then
	echo "CageLab status check failed: jq is required to parse the API response JSON."
	exit 1
fi

response=$(curl -fsS --connect-timeout 3 --max-time 5 --location --request GET "$status_url" 2>/dev/null)
curl_status=$?

if [[ $curl_status -ne 0 || -z "$response" ]]; then
	echo "CageLab service status is unavailable: could not reach $status_url"
	exit 1
fi

is_running=$(printf '%s' "$response" | jq -r 'if (.is_running | type) == "boolean" then .is_running else error("invalid is_running") end')
parse_status=$?

if [[ $parse_status -ne 0 ]]; then
	echo "CageLab service status is unavailable: API response did not contain a valid is_running value."
	exit 1
fi

if [[ "$is_running" == "true" ]]; then
	echo "CageLab service is running."
else
	echo "CageLab service is not running."
fi