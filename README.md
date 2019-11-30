# Landing Zone Security Hub action

Automatically installs Security Hub in accounts created by the Landing Zone AVM and connects them back to the Security account 

## Inputs

### `SECURITYHUB_USER_ID`

**Required** AWS Access Key for your Security Hub User.

### `SECURITYHUB_ACCESS_KEY`

**Required** AWS Secret Key for your Security Hub User.

### `SECURITYHUB_CROSSACCOUNT_ROLE`

**Required** ARN of the role AWSLandingZoneSecurityHubRole in the security account.

### `SECURITYHUB_LISTACCOUNTS_ROLE`

**Required** ARN of the role AWSLandingZoneReadOnlyListAccountsRole in the primary account.

### `SECURITYHUB_EXECUTION_ROLE`

**Required** Name of the role AWSLandingZoneSecurityHubExecutionRole in the target accounts.

### `SECURITYHUB_REGIONS`

**Required** Comma separated list of regions where Security Hub must be deployed. If not present, will deploy everywhere.

## Example usage

```yaml
uses: madeden/lz-actions-securityhub@master
with:
  SECURITYHUB_USER_ID: ${{ secrets.SECURITYHUB_USER_ID }}
  SECURITYHUB_ACCESS_KEY: ${{ secrets.SECURITYHUB_ACCESS_KEY }}
  SECURITYHUB_CROSSACCOUNT_ROLE: ${{ secrets.SECURITYHUB_CROSSACCOUNT_ROLE }}
  SECURITYHUB_LISTACCOUNTS_ROLE: ${{ secrets.SECURITYHUB_LISTACCOUNTS_ROLE }}
  SECURITYHUB_EXECUTION_ROLE: ${{ secrets.SECURITYHUB_EXECUTION_ROLE }}
  SECURITYHUB_REGIONS: ${{ secrets.SECURITYHUB_REGIONS }}
```

The action uses the IAM credentials from a user in the security account to assume the AWSLandingZoneSecurityHubRole in the security account. 

After that it uses the obtained credentials to assume the AWSLandingZoneReadOnlyListAccountsRole, which in turns serves to retrieve the list of available accounts.
That list is then converted into the CSV file that can be consumed by the script to add accounts to the Security Hub 

Then using the IAM user credentials it assumes the AWSLandingZoneSecurityHubExecutionRole in every existing account to launch in parallel prowler for each account.

# Required changes in the LZ for letting the action work

By default the Landing Zone product doesn't provide the required components for this action to work outside of AWS. 
We decided to create an IAM user and group that can impersonate a role in the Security account to chain assume roles in the primary account (ListAccounts) then in every account to configure the Security Huband allowed it to assume the different roles for listing accounts and performing the actual security scan.

Read move about this in the documentation of the Landing Zone.  

