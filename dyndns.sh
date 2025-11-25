#!/bin/sh
# DynDNS Script for Hetzner Cloud API
# v2.0 - Updated for new Cloud API (api.hetzner.cloud)

# get OS environment variables
auth_api_token=${HETZNER_AUTH_API_TOKEN:-''}

zone_name=${HETZNER_ZONE_NAME:-''}
zone_id=${HETZNER_ZONE_ID:-''}

record_name=${HETZNER_RECORD_NAME:-''}
record_ttl=${HETZNER_RECORD_TTL:-'60'}
record_type=${HETZNER_RECORD_TYPE:-'A'}

display_help() {
  cat <<EOF

exec: ./dyndns.sh [ -z <Zone ID> | -Z <Zone Name> ] -n <Record Name>

parameters:
  -z  - Zone ID
  -Z  - Zone name
  -n  - Record name (e.g., "dyn" for dyn.example.com, or "@" for root domain)

optional parameters:
  -t  - TTL (Default: 60)
  -T  - Record type (Default: A, supports: A, AAAA)

help:
  -h  - Show Help

requirements:
  curl
  jq

example:
  .exec: ./dyndns.sh -z 98jFjsd8dh1GHasdf7a8hJG7 -n dyn
  .exec: ./dyndns.sh -Z example.com -n dyn -T AAAA
  .exec: ./dyndns.sh -Z example.com -n @ -T A

Note: This script uses the new Hetzner Cloud API (api.hetzner.cloud).
      Requires an API token from https://console.hetzner.cloud/

EOF
  exit 1
}

logger() {
  echo ${1}: Record_Name: ${record_name} : ${2}
}

while getopts ":z:Z:n:t:T:h" opt; do
  case "$opt" in
    z  ) zone_id="${OPTARG}";;
    Z  ) zone_name="${OPTARG}";;
    n  ) record_name="${OPTARG}";;
    t  ) record_ttl="${OPTARG}";;
    T  ) record_type="${OPTARG}";;
    h  ) display_help;;
    \? ) echo "Invalid option: -$OPTARG" >&2; exit 1;;
    :  ) echo "Missing option argument for -$OPTARG" >&2; exit 1;;
    *  ) echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
done

# Check if tools are installed
for cmd in curl jq; do
  if ! command -v "${cmd}" &> /dev/null; then
    logger Error "To run the script '${cmd}' is needed, but it seems not to be installed."
    exit 1
  fi
done

# Check if api token is set
if [[ "${auth_api_token}" = "" ]]; then
  logger Error "No Auth API Token specified."
  logger Error "Set HETZNER_AUTH_API_TOKEN environment variable or edit the script."
  exit 1
fi

# API base URL for Hetzner Cloud
api_base_url="https://api.hetzner.cloud/v1"

# get all zones
zone_info=$(curl -s --location \
          "${api_base_url}/zones" \
          --header "Authorization: Bearer ${auth_api_token}")

# Debug: Check what we received
if [[ "${zone_info}" = "" ]]; then
  logger Error "No response from API. Check your network connection and API endpoint."
  exit 1
fi

# Check for API errors
if echo "${zone_info}" | jq -e '.error' > /dev/null 2>&1; then
  error_message=$(echo "${zone_info}" | jq -r '.error.message')
  error_code=$(echo "${zone_info}" | jq -r '.error.code')
  logger Error "API Error (${error_code}): ${error_message}"
  exit 1
fi

# Check if zones exist in response
zone_count=$(echo "${zone_info}" | jq -r '.zones | length')
if [[ "${zone_count}" = "0" || "${zone_count}" = "null" ]]; then
  logger Error "No zones found in your Hetzner account."
  logger Error "Please create a zone first at https://console.hetzner.cloud/"
  logger Error "API Response: ${zone_info}"
  exit 1
fi

# get zone_id if zone_name is given and in zones
if [[ "${zone_id}" = "" && "${zone_name}" != "" ]]; then
  zone_id=$(echo ${zone_info} | jq --raw-output '.zones[] | select(.name=="'${zone_name}'") | .id')
fi

# get zone_name if zone_id is given and in zones
if [[ "${zone_name}" = "" && "${zone_id}" != "" ]]; then
  zone_name=$(echo ${zone_info} | jq --raw-output '.zones[] | select(.id=='${zone_id}') | .name')
fi

# check if either zone_id or zone_name is correct
if [[ "${zone_id}" = "" || "${zone_name}" = "" ]]; then
  logger Error "Something went wrong. Could not find Zone ID."
  logger Error "Check your inputs of either -z <Zone ID> or -Z <Zone Name>."
  logger Error "Available zones:"
  echo ${zone_info} | jq -r '.zones[] | "  ID: \(.id) - Name: \(.name)"'
  exit 1
fi

logger Info "Zone_ID: ${zone_id}"
logger Info "Zone_Name: ${zone_name}"

if [[ "${record_name}" = "" ]]; then
  logger Error "Missing option for record name: -n <Record Name>"
  logger Error "Use -h to display help."
  exit 1
fi

# For Hetzner Cloud API, we need to use just the subdomain (record_name)
# The API automatically handles the zone association
# Special case: "@" or empty means the zone apex (root domain)
if [[ "${record_name}" = "@" ]]; then
  api_record_name="${zone_name}"
elif [[ "${record_name}" == *".${zone_name}" ]]; then
  # record_name already includes the zone, strip it to get just the subdomain
  api_record_name="${record_name%.${zone_name}}"
else
  # Use record_name as-is (just the subdomain part)
  api_record_name="${record_name}"
fi

# For display and logging, construct the FQDN
if [[ "${record_name}" = "@" ]]; then
  full_record_name="${zone_name}"
else
  full_record_name="${record_name}.${zone_name}"
fi

logger Info "API_Record_Name: ${api_record_name}"
logger Info "Full_Record_Name (FQDN): ${full_record_name}"

# get current public ip address
if [[ "${record_type}" = "AAAA" ]]; then
  logger Info "Using IPv6, because AAAA was set as record type."
  cur_pub_addr=$(curl -s6 https://ip.hetzner.com | grep -E '^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$')
  if [[ "${cur_pub_addr}" = "" ]]; then
    logger Error "It seems you don't have a IPv6 public address."
    exit 1
  else
    logger Info "Current public IP address: ${cur_pub_addr}"
  fi
elif [[ "${record_type}" = "A" ]]; then
  logger Info "Using IPv4, because A was set as record type."
  cur_pub_addr=$(curl -s4 https://ip.hetzner.com | grep -E '^([0-9]+(\.|$)){4}')
  if [[ "${cur_pub_addr}" = "" ]]; then
    logger Error "Apparently there is a problem in determining the public ip address."
    exit 1
  else
    logger Info "Current public IP address: ${cur_pub_addr}"
  fi
else
  logger Error "Only record type \"A\" or \"AAAA\" are supported for DynDNS."
  exit 1
fi

# Get existing RRsets for this zone (using just the subdomain name)
rrsets_info=$(curl -s --location \
               --request GET "${api_base_url}/zones/${zone_id}/rrsets?name=${api_record_name}&type=${record_type}" \
               --header "Authorization: Bearer ${auth_api_token}")

# Check for API errors
if echo "${rrsets_info}" | jq -e '.error' > /dev/null 2>&1; then
  error_message=$(echo "${rrsets_info}" | jq -r '.error.message')
  logger Error "API Error: ${error_message}"
  exit 1
fi

# Check if the record exists (API returns full FQDN in responses, but we query with subdomain)
existing_record=$(echo ${rrsets_info} | jq --raw-output '.rrsets[] | select(.type=="'${record_type}'")')

# create a new record
if [[ "${existing_record}" = "" ]]; then
  logger Info "DNS record \"${full_record_name}\" does not exist - will be created."

  create_response=$(curl -s -w "\n%{http_code}" -X "POST" "${api_base_url}/zones/${zone_id}/rrsets" \
       -H 'Content-Type: application/json' \
       -H "Authorization: Bearer ${auth_api_token}" \
       -d '{
          "name": "'${api_record_name}'",
          "type": "'${record_type}'",
          "ttl": '${record_ttl}',
          "records": [
            {
              "value": "'${cur_pub_addr}'"
            }
          ]
        }')

  http_code=$(echo "${create_response}" | tail -n 1)
  response_body=$(echo "${create_response}" | sed '$d')

  if [[ "${http_code}" = "201" ]]; then
    logger Info "DNS record \"${full_record_name}\" created successfully"
    # Show what was actually created
    created_name=$(echo "${response_body}" | jq -r '.rrset.name')
    logger Info "API returned record name: ${created_name}"
  else
    logger Error "Failed to create record. HTTP Status: ${http_code}"
    logger Error "Response body: ${response_body}"
    if echo "${response_body}" | jq -e '.error' > /dev/null 2>&1; then
      error_message=$(echo "${response_body}" | jq -r '.error.message')
      logger Error "API Error: ${error_message}"
    fi
    exit 1
  fi
else
  # check if update is needed
  cur_dyn_addr=$(echo ${existing_record} | jq --raw-output '.records[0].value')

  logger Info "Currently set IP address: ${cur_dyn_addr}"

  # update existing record
  if [[ $cur_pub_addr == $cur_dyn_addr ]]; then
    logger Info "DNS record \"${full_record_name}\" is up to date - nothing to do."
    exit 0
  else
    logger Info "DNS record \"${full_record_name}\" is no longer valid - updating record"

    # Update the record using the API record name
    update_response=$(curl -s -w "\n%{http_code}" -X "PUT" "${api_base_url}/zones/${zone_id}/rrsets/${api_record_name}/${record_type}" \
         -H 'Content-Type: application/json' \
         -H "Authorization: Bearer ${auth_api_token}" \
         -d '{
           "ttl": '${record_ttl}',
           "records": [
             {
               "value": "'${cur_pub_addr}'"
             }
           ]
         }')

    http_code=$(echo "${update_response}" | tail -n 1)
    response_body=$(echo "${update_response}" | sed '$d')

    if [[ "${http_code}" = "200" ]]; then
      logger Info "DNS record \"${full_record_name}\" updated successfully"
    else
      logger Error "Failed to update record. HTTP Status: ${http_code}"
      if echo "${response_body}" | jq -e '.error' > /dev/null 2>&1; then
        error_message=$(echo "${response_body}" | jq -r '.error.message')
        logger Error "API Error: ${error_message}"
      fi
      exit 1
    fi
  fi
fi
