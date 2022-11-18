#!/bin/bash

# Reset all variables to blank
S1_ACCOUNT_ID=''
S1_API_KEY=''
S1_HOSTNAME=''
S1_ROLE_ID=''
S1_INITIAL_PW=''
S1_2FA=''
int=2;


Color_Off='\033[0m'       # Text Resets
NORMAL='\033[0m'
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
BOLD='\033[1m'		  # Bold

set -e # exit on failure

# Checking dependencies
if [ ! -f '/usr/bin/curl' ]; then 
  echo -e "${Red}Error:${NORMAL} CURL is not installed. This is a requirement. "
  exit # Exit if CURL is not installed
fi

# JQ is a binary that does some clever JSON parsing. Not essential for script but nice to have
if [ ! -f '/usr/bin/jq' ]; then 
  jqInstall='false'
else
  jqInstall='true'
fi


# Determine if any parameters, if not, ask questions!
if [[ $# -eq 0 ]] ; then
  printf "${BOLD}Usage:${NORMAL}\n"
  printf "  ./adduser.sh ${Green}<CSV Userlist>${NORMAL}\n"
  printf "${BOLD}CSV file format:${NORMAL}\n"
  printf "${Purple}  fullname,emailaddress${NORMAL}\n"
  printf "or\n"
  printf "${Purple}  firstname,surname,emailaddress${NORMAL}\n" 
  exit
fi


if [ ! -f $1 ] ; then 
    printf "${Red}Error:${NORMAL} CSV file not found.\n" # Error if no file is found
    exit
fi

if [ -f "auth.key" ]; then
  echo -e "${BOLD}Located ${Green}${BOLD}auth.key${NORMAL}${BOLD}, reading variables...${NORMAL}"
  noauthkey='false'
  source "auth.key" # If auth.key is found in current folder, read in the values
else
  echo -e "${Green}${BOLD}auth.key${NORMAL}${BOLD} not found, prompting for variables...${NORMAL}\n"
  noauthkey='true'
fi

S1_2FA=$(echo $S1_2FA | tr '[:upper:]' '[:lower:]') # Convert variable to lowercase

# Loop until a URL is entered that is routable
while [ $int -eq 2 ]; do
  while [[ $S1_HOSTNAME == "" ]]; do
      echo -e "      ${BOLD}S1 Console URL: ${NORMAL}\c" && read S1_HOSTNAME
  done

  # Strip trailing / from the URL
  S1_HOSTNAME=$(echo $S1_HOSTNAME | sed 's:/*$::')
  # Check for https:// and add it if missing
  https=$(echo $S1_HOSTNAME | awk '{ print substr($1,1,8)}')
  if [[ $https != "https://" ]]; then
     S1_HOSTNAME="https://$S1_HOSTNAME"
  fi
  
  # Validate site and error out if not valid/routable
  if curl --output /dev/null --silent --head --fail "$S1_HOSTNAME"; then
    int=0
  
    if [[ $noauthkey == "true" ]]; then  
      echo -e "            ${BOLD}Full URL: ${NORMAL}${Green}$S1_HOSTNAME${NORMAL}"
    fi
    break # All good, break out of while loop
  else
    echo -e "${Red}${BOLD}               Error:${NORMAL} Site $S1_HOSTNAME is invalid, please enter a routable URL"
    int=2
    S1_HOSTNAME=""
  fi
  
done

# Loop until API key is 80 characters
while [ ${#S1_API_KEY} != 80 ]; do
  while [[ $S1_API_KEY == "" ]] ; do
   echo -e "        ${BOLD}S1 API Token: ${NORMAL}\c" && read S1_API_KEY
  done

  # Checking length of API key is 80 characters
  if [ ${#S1_API_KEY} != 80 ]; then
    echo -e "${Red}${BOLD}               Error:${NORMAL} API Key not valid, should be 80 characters, currently ${#S1_API_KEY} characters"
    S1_API_KEY=""
  else
    break  # success break out of loop
  fi
done;

# Read S1 Account ID
while [[ $S1_ACCOUNT_ID == "" ]] ; do
  echo -e "          ${BOLD}Account ID: ${NORMAL}\c" && read S1_ACCOUNT_ID
done

# Read S1 Role ID
while [[ $S1_ROLE_ID == "" ]] ; do
  echo -e "             ${BOLD}Role ID: ${NORMAL}\c" && read S1_ROLE_ID
done

# Read S1 Initial PW
while [[ $S1_INITIAL_PW == "" ]] ; do
  echo -e "    ${BOLD}Initial Password: ${NORMAL}\c" && read S1_INITIAL_PW
done

# Loop until an answer is Yes or No for 2FA
while :; do
  if [[ $S1_2FA == "Y" ]] || [[ $S1_2FA == "N" ]] || [[ $S1_2FA == "true" ]] || [[ $S1_2FA == "false" ]]; then 
    break # we have a valid response
  fi;
  echo -e "${BOLD}Enable 2FA (Y/N) [Y]: ${NORMAL}\c"  && read ans
  S1_2FA=$(echo $ans | tr '[:lower:]' '[:upper:]')
  if [[ $S1_2FA == "Y" ]] || [[ $S1_2FA == "N" ]] || [[ $S1_2FA == "true" ]] || [[ $S1_2FA == "false" ]] || [[ $S1_2FA == "" ]]; then 
    if [[ $S1_2FA == "" ]]; then 
      S1_2FA="Y"
      break 
    fi
    echo -e "Invalid input, Y, N or Enter"; 
  fi;
done

# Validate 2FA settings
if [[ $S1_2FA == 'Y' ]] || [[ $S1_2FA == 'true' ]]; then S1_2FA='true'; else S1_2FA='false'; fi;

# Set up variables for CURL request
header1="Authorization: ApiToken $S1_API_KEY"
header2="Content-Type: application/json"

# If JQ is installed, let's add some extra information to the check
if [[ $jqInstall == 'true' ]]; then
    endpoint="/web/api/v2.1/accounts?accountIds=$S1_ACCOUNT_ID"
    url="$S1_HOSTNAME$endpoint"
    http_response=$(curl -o /dev/null -s -w "%{http_code}" --request GET --header "$header1" --header "$header2" "$url"  2>&1 ) # Get the JSON output
   
    # Output any errors based on response code
    case $http_response in
      200)
        http_response=$(curl -s --request GET --header "$header1" --header "$header2" "$url" | jq '.data[].name' )
        accountName="${BOLD}($http_response)${NORMAL}"
      ;;
      401)
        echo -e " - ${Red}Error:${NORMAL} Unauthorised. Check API, permissions and double check the S1 Console URL"
        exit # Failed authenticaion
      ;;
      404)
        echo -e " - ${Red}Error $http_response:${NORMAL} Content not found. Check the S1 URL is correct"
        exit; 
      ;;
      *)
        echo -e " - ${Red}Error $http_response:${NORMAL} Unknown error"
        exit
      ;;
    esac
    
    # Set headers to get Role ID
    endpoint="/web/api/v2.1/rbac/role/$S1_ROLE_ID"
    url="$S1_HOSTNAME$endpoint"
    http_response=$(curl -o /dev/null -s -w "%{http_code}" --request GET --header "$header1" --header "$header2" "$url" 2>&1 )  
    case $http_response in
      200)
        http_response=$(curl -s --request GET --header "$header1" --header "$header2" "$url" | jq '.data.description' )
        roleName="${BOLD}($http_response)${NORMAL}"
      ;;
      401)
        echo -e " - ${Red}Error:${NORMAL} Unauthorised. Check API and permissions"
        exit # Failed authentication
      ;;
      *)
        echo -e " - ${Red}Error $http_response:${NORMAL} Unknown error"
        exit
      ;;
    esac
fi

# Display summary of output
apiDisplay=$(echo $S1_API_KEY | awk '{ print substr($1,1,8) }')'....' # Don't show the full API key out
printf "\n"
printf "       ${Purple}S1 Console:${NORMAL} $S1_HOSTNAME\n"
printf "     ${Purple}S1 API Token:${NORMAL} $apiDisplay\n"
printf "       ${Purple}Account ID:${NORMAL} $S1_ACCOUNT_ID $accountName\n"
printf "          ${Purple}Role ID:${NORMAL} $S1_ROLE_ID $roleName\n"
printf "       ${Purple}Initial PW:${NORMAL} $S1_INITIAL_PW\n"
printf "       ${Purple}Enable 2FA:${NORMAL} $S1_2FA\n"

endpoint='/web/api/v2.1/users'
url="$S1_HOSTNAME$endpoint"

# Write record to screen
echo -e "${Purple}\nCreating the following users in S1...${NORMAL}"
while IFS=',' read -a csvArray # Read each line from the CSV File
do
    lowerfirst=$(echo ${csvArray[0]} | tr '[:upper:]' '[:lower:]') # Convert from upper to lowercase
    if [[ $lowerfirst != "first name" ]] && [[ ${csvArray[0]} != "" ]]; then # If first line contains First Name, then skip as header row
      if (( ${#csvArray[@]} == 3 )); then # If 3 fields, first, last, email
          fullname="${csvArray[0]} ${csvArray[1]}"
          email="${csvArray[2]}"
        else # if 2 fields, full name, email
          fullname="${csvArray[0]}"
          email="${csvArray[1]}"
        fi
        echo -e " - $fullname ($email)"
    fi
done < $1
echo -e ""
while [ "$retryconfirm" != "y" ] && [ "$retryconfirm" != "Y" ] && [ "$retryconfirm" != "N" ] && [ "$retryconfirm" != "n" ] ; do
    echo -e "Is the above correct? (${Green}Y${NORMAL}/${Red}N${NORMAL}): \c" && read retryconfirm
done
if [ $retryconfirm == "n" ] || [ $retryconfirm == "N" ] ; then
    echo
    echo "Aborting ..."
    echo
    exit
fi

# Write record to S1
while IFS=',' read -a csvArray
do
    lowerfirst=$(echo ${csvArray[0]} | tr '[:upper:]' '[:lower:]') # Convert from upper to lowercase
    if [[ $lowerfirst != "first name" ]] && [[ ${csvArray[0]} != "" ]]; then # If first line contains First Name, then skip as header row
        if (( ${#csvArray[@]} == 3 )); then # If 3 fields, first, last, email
          fullname="${csvArray[0]} ${csvArray[1]}"
          email="${csvArray[2]}"
        else # if 2 fields, full name, email
          fullname="${csvArray[0]}"
          email="${csvArray[1]}"
        fi

        # Create the JSON body
        body="{
                        \"data\": {
                            \"scopeRoles\": [
                            {
                                \"id\": \"$S1_ACCOUNT_ID\",
                                \"roleId\": \"$S1_ROLE_ID\"
                            }
                            ],
                        \"email\": \"$email\",
                        \"scope\": \"account\",
                        \"twoFaEnabled\": \"$S1_2FA\",
                        \"password\": \"$S1_INITIAL_PW\",
                        \"fullName\": \"${fullname}\",
                        \"allowRemoteShell\": \"true\"
                        }
                    }"
        http_response=$(curl -o /dev/null -s -w "%{http_code}" --request POST "$url" --header "$header1" --header "$header2" --data "$body"  )
        echo -e "${Purple}Creating $fullname in S1:${NORMAL}"
        
        # Output any errors
        if [[ $http_response != "200" ]]; then
            case $http_response in
            401)
                echo -e " - ${Red}Error:${NORMAL} not created - unauthorised. Check API and permissions"
            ;;
            400)
                echo -e " - ${Red}Error:${NORMAL} ${BOLD}${csvArray[2]}${NORMAL} already exists, please use an unique email address."
            ;;
            *)
                echo -e " - ${Red}Error $http_response:${NORMAL} Unknown error"
            ;;
            esac
        else
            echo -e " - ${Green}Success:${NORMAL} User $fullname (${csvArray[2]}) created successfully"
        fi
    fi 
done < $1
