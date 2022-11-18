# S1-Add-Users
Script to bulk import users in to S1 console, specifying Role ID and Account ID

## Dependencies
You need CURL installed for this to work. Optionally, jq should be installed for JSON parsing, but not essential. JQ library will be used to populate the Account and Role ID as human name.

## Usage
```
./adduser.sh <CSV Userlist>
```
The CSV file format can be either a 2-field or 3-field format as follows:
```
firstname,lastname,email
fullname,email
```

## auth.key (optional)
A sample auth.key is supplied and, if placed in the same folder as adduser.sh, the parameters will be read from that file. If there is no auth.key file, then the script will prompt for the parameters. You can also put partial values in this file - any that are missing will be prompted on execution. 

## Parameters
* S1 Console - this is the full FQDN of the SentinelOne console. https will be added if not present, and any trailing /'s are removed
* S1 API Token - a full read/write API token is required for updating the S1 console, this must be 80 characters
* S1 Account ID - obtain the S1 Account ID from within the S1 Console of where you want to create the users
* S1 Role ID - obtain the S1 Role ID for the role that needs to be assigned to the users. The ID is available in the S1 Console under Roles
* Initial Password - this will be the inital password set for the accounts
* Enable 2FA - true or false, will enable 2FA for the user

Validation is done on the URL and API key to ensure a correct value is created. 

Error codes are validated, when applying to indicate if successful, if authentication has failed, or if the email address already exists in the S1 Console. 
