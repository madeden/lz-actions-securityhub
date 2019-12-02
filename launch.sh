#!/bin/bash

DEBUG="true"

abort(){
  echo "$1"
  exit 1;
}

check_exec(){
  echo "Checking $1..."
  command -v "$1" >/dev/null 2>&1;
}

check_env(){
  echo "Checking environment"
  CHECK_EXECS="aws jq"
  for x in $CHECK_EXECS
  do  
    check_exec "$x" || abort "Unable to find $x"
  done
}

assume_role(){
  local STS_ROLE="$1"      
  local JSON_STS=""

  if [ -z "$STS_ROLE" ]; then
    abort "You must provide a role arn :("
  fi

  if [ "$DEBUG" == "true" ]; then
        aws sts get-caller-identity || abort "Unable to determine caller identity :("
  fi

  local unix_timestamp
  unix_timestamp=$(date +%s%N | cut -b1-13)

  JSON_STS=$(aws sts assume-role --role-arn "$STS_ROLE"  --role-session-name "session-$unix_timestamp")

  if [ -z "$JSON_STS" ]; then
    abort "Unable to assume role :("
  fi        

  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN

  export AWS_ACCESS_KEY_ID=$(echo "$JSON_STS" | jq -r .Credentials.AccessKeyId)
  export AWS_SECRET_ACCESS_KEY=$(echo "$JSON_STS" | jq -r .Credentials.SecretAccessKey)
  export AWS_SESSION_TOKEN=$(echo "$JSON_STS" | jq -r .Credentials.SessionToken)

  unset STS_ROLE
  unset JSON_STS
}

organizations_list_accounts_to_csv(){
  local OUTPUT="$1"
  local ACCOUNTS
  
  ACCOUNTS=$(aws organizations list-accounts)

  if [ -z "$ACCOUNTS" ]; then
    abort "Unable to list accounts :("
  fi

  echo "AccountId,EmailAddress" > "${OUTPUT}"

  jq -r '.Accounts[] | [ .Id, .Email ] | @csv' <<< "${ACCOUNTS}" | tr -d \" >> "${OUTPUT}"
}

check_input(){
  if [ -z "$1" ]; then
    abort "You must provide the IAM USER ID :("
  fi

  if [ -z "$2" ]; then
    abort "You must provide the IAM USER CREDENTIALS :("
  fi

  if [ -z "$3" ]; then
    abort "You must provide the SecurityHubRoleName ARN (From the security account)"
  fi

  if [ -z "$4" ]; then
    abort "You must provide the AWSLandingZoneReadOnlyListAccountsRole ARN (From the primary/master account)"
  fi

  if [ -z "$5" ]; then
    abort "You must provide the AWSLandingZoneSecurityHubExecutionRole name (!! NOT ARN) for target accounts"
  fi

  if [ -z "$6" ]; then
    echo "As you did not provide a comma separated list of regions to enable SecurityHub it will be enabled in all available regions"
  fi
}

#Validate input parameters
if [ "$#" -lt 5 ]; then
  abort "Invalid number of parameters :("
fi

SECURITYHUB_USER_ID="$1"
SECURITYHUB_ACCESS_KEY="$2"
SECURITYHUB_CROSSACCOUNT_ROLE="$3"
SECURITYHUB_LISTACCOUNTS_ROLE="$4"
SECURITYHUB_EXECUTION_ROLE="$5"
SECURITYHUB_REGIONS="${6:+noregions}"

check_input "$SECURITYHUB_USER_ID" "$SECURITYHUB_ACCESS_KEY" "$SECURITYHUB_CROSSACCOUNT_ROLE" "$SECURITYHUB_LISTACCOUNTS_ROLE" "$SECURITYHUB_EXECUTION_ROLE"

#Set internal variables from the parameters (which are also environment variables)
export AWS_ACCESS_KEY_ID="$SECURITYHUB_USER_ID"
export AWS_SECRET_ACCESS_KEY="$SECURITYHUB_ACCESS_KEY"
export AWS_SESSION_TOKEN=""
PRIMARY_SECURITY_ACCOUNT_ROLE="$SECURITYHUB_CROSSACCOUNT_ROLE"
DEPLOY_ROLE="$SECURITYHUB_EXECUTION_ROLE"
LIST_ACCOUNTS_ROLE="$SECURITYHUB_LISTACCOUNTS_ROLE"
SECURITY_ACCOUNT_ID=$(cut -f5 -d: <<< "$PRIMARY_SECURITY_ACCOUNT_ROLE")
CSV_FILE="/tmp/organization.csv"

if [ -z "$SECURITYHUB_REGIONS" ]; then
  REGION_STRING=""
else
  REGION_STRING="--enabled-regions ${SECURITYHUB_REGIONS}"
fi

# List accounts retrieving the ID and store them in a CSV file
check_env
assume_role "$PRIMARY_SECURITY_ACCOUNT_ROLE"
assume_role "$LIST_ACCOUNTS_ROLE"
organizations_list_accounts_to_csv "$CSV_FILE"

# Execute the script on CSV file as the security user
export AWS_ACCESS_KEY_ID="$SECURITYHUB_USER_ID"
export AWS_SECRET_ACCESS_KEY="$SECURITYHUB_ACCESS_KEY"
export AWS_SESSION_TOKEN=""
assume_role "$PRIMARY_SECURITY_ACCOUNT_ROLE"
/${USERNAME}/enablesecurityhub.py --master_account "$SECURITY_ACCOUNT_ID" \
  --assume_role "$DEPLOY_ROLE" \
  "$REGION_STRING" \
  "$CSV_FILE"
