# Manually deploy Redcap using PowerShell

### Prerequisites:

Install the following prerequisites on your local machine:
- **[PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell?view=powershell-7.3)**
- **[Az PowerShell module](https://learn.microsoft.com/powershell/azure/new-azureps-module-az?view=azps-10.3.0)**
- **[Bicep tools](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)**
- **[Git](https://git-scm.com/downloads)**
- **[Visual Studio Code](https://code.visualstudio.com/download)**

### Deployment Steps:
Perform the following steps to deploy the solution using PowerShell:

- Fork this repository and clone it to your administrative workstation or alternatively you can just clone the repository and work with it directly:
  - To clone the repository and work with it directly, run the following command:

    ```powershell
    git clone https://github.com/Microsoft/azure-redcap-paas.git
    ```
- Open the `azure-redcap-paas` folder in VSCode

- Copy `main-sample.bicepparam` to a new file with a descriptive name, such as `main-*yourorg*.bicepparam`

- Review and modify the parameter values in the `main-*yourorg*.bicepparam` file as needed. Here is the summary of parameters:
  - ***location***: The region where the resources will be deployed. The example of this parameter is `eastus`
  - ***environment***: The name of the enviorment for this deployed value. Allowed values are `test`, `demo`, `prod`. The example of this parameter is `test`
  - ***workloadName***: The name of the workload. The example of this parameter is `redcap`
  - ***sequenceNumber***: The sequence number of the deployment. The example of this parameter is `1`. If you are deploying the same workload multiple times, you need to increment this number for each deployment.
  - ***identityObjectId***: Valid Entra ID object ID for permissions assignment. This identity object will be assigned admin access. The example of this parameter is `00000000-0000-0000-0000-000000000000`
  - ***vnetAddressPrefix***: The address prefix for the virtual network. The example of this parameter is `192.168.1.0/24`
  - ***redcapZipUrl***: The URL to the Redcap zip file.
  - ***redcapCommunityUsername***: This is not required if redcapZipUrl is provided. Else The username for the Redcap community site.
  - ***redcapCommunityPassword***: This is not required if redcapZipUrl is provided. Else The password for the Redcap community site.
  - ***scmRepoUrl***: If you have fork the repo, provide the URL to your forked repo. Else provide the URL to the original repo.
  - ***scmRepoBranch***: The branch of the repo to deploy from. The example of this parameter is `main`
- Execute `deploy.ps1` as shown below.

    ```PowerShell
        ./deploy.ps1 -Location 'eastus' -TemplateParameterFile 'main-yourorg.bicepparam' -SubscriptionId 'subscription-id'
    ```

- You may omit the parameter names and use them in the order `Location`, `TemplateParameterFile`, and `SubscriptionId`

    ```PowerShell
        ./deploy.ps1 'eastus' 'main-yourorg.bicepparam' 'subscription-id'
    ```
