targetScope = 'subscription'

/*
 * This module creates a value for an App Service or Function App setting that references a Key Vault secret.
 */

@description('The names of the Key Vault secrets to create references for.')
param secretNames array
@description('The name of the Key Vault where the secrets are stored.')
param keyVaultName string

output keyVaultRefs array = [for secretName in secretNames: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${secretName})']
