/*
 * Creates a short name for the given structure and values that is no longer than the maximum specified length
 * How this is shorter than the standard naming convention
 * - Saves usually 1 character on the sequence (01 vs. 1)
 * - Saves a few characters in the location name (eastus vs. eus)
 * - Takes only the first character of the environment (prod = p, demo or dev = d, test = t)
 * - Ensures the max length does not exceed the specified value
 */
targetScope = 'subscription'

param namingConvention string
param location string
@allowed([
  'vnet' // Virtual Network
  'kv' // Key Vault
  'st' // Storage Account
  'cr' // Container Registry
  'pg' // PostgreSQL Flexible Server
  'ci' // Container Instance
  'mysql' // MySQL Flexible Server
  'app' // Web App
  'plan' // App Service Plan
  'appi' // Application Insights
  'uami' // User-assigned Managed Identity
  'dplscr' // Deployment Script
  'law' // Log Analytics Workspace
])
param resourceType string
param environment string
param workloadName string
param subWorkloadName string = ''
param sequence int

@description('If true, the name will always use short versions of placeholders. If false, it will only be shortened when needed to fit in the maxLength.')
param requireShorten bool = false
@description('If true, hyphens will be removed from the name. If false, they will only be removed if required by the resource type.')
param removeSegmentSeparator bool = false

@allowed([
  '-'
  '_'
])
param segmentSeparator string = '-'

@description('If true, when creating a short name, vowels will first be removed from the workload name.')
param useRemoveVowelStrategy bool = false

@maxValue(13)
param addRandomChars int = 0
@description('When using addRandomChars > 0, generated resource names will be idempotent for the same resource group, workload, resource location, environment, sequence, and resource type. If an additional discrimnator is required, provide the value here.')
param additionalRandomInitializer string = ''

// Define the behavior of this module for each supported resource type
var Defs = {
  vnet: {
    lowerCase: false
    maxLength: 64
    alwaysRemoveSegmentSeparator: false
  }
  plan: {
    lowerCase: false
    maxLength: 60
    alwaysRemoveSegmentSeparator: false
  }
  app: {
    lowerCase: false
    maxLength: 60
    alwaysRemoveSegmentSeparator: false
  }
  kv: {
    lowerCase: false
    maxLength: 24
    alwaysRemoveSegmentSeparator: false
  }
  st: {
    lowerCase: true
    maxLength: 24
    alwaysRemoveSegmentSeparator: true
  }
  cr: {
    lowerCase: false
    maxLength: 50
    alwaysRemoveSegmentSeparator: true
  }
  pg: {
    lowerCase: true
    maxLength: 63
    alwaysRemoveSegmentSeparator: false
  }
  ci: {
    lowerCase: true
    maxLength: 63
    alwaysRemoveSegmentSeparator: false
  }
  mysql: {
    lowerCase: true
    maxLength: 63
    alwaysRemoveSegmentSeparator: false
  }
  appi: {
    lowerCase: false
    maxLength: 260
    alwaysRemoveSegmentSeparator: false
  }
  uami: {
    lowerCase: false
    maxLength: 128
    alwaysRemoveSegmentSeparator: false
  }
  dplscr: {
    lowerCase: false
    maxLength: 63 // Guess, not documented
    alwaysRemoveSegmentSeparator: false
  }
  law: {
    lowerCase: false
    maxLength: 63
    alwaysRemoveSegmentSeparator: false
  }
}

var shortLocations = {
  australiacentral: 'acl'
  'Australia Central': 'acl'
  australiacentral2: 'acl2'
  'Australia Central 2': 'acl2'
  australiaeast: 'ae'
  'Australia East': 'ae'
  australiasoutheast: 'ase'
  'Australia Southeast': 'ase'
  brazilsouth: 'brs'
  'Brazil South': 'brs'
  brazilsoutheast: 'bse'
  'Brazil Southeast': 'bse'
  centraluseuap: 'ccy'
  'Central US EUAP': 'ccy'
  canadacentral: 'cnc'
  'Canada Central': 'cnc'
  canadaeast: 'cne'
  'Canada East': 'cne'
  centralus: 'cus'
  'Central US': 'cus'
  eastasia: 'ea'
  'East Asia': 'ea'
  eastus2euap: 'ecy'
  'East US 2 EUAP': 'ecy'
  eastus: 'eus'
  'East US': 'eus'
  eastus2: 'eus2'
  'East US 2': 'eus2'
  francecentral: 'frc'
  'France Central': 'frc'
  francesouth: 'frs'
  'France South': 'frs'
  germanynorth: 'gn'
  'Germany North': 'gn'
  germanywestcentral: 'gwc'
  'Germany West Central': 'gwc'
  centralindia: 'inc'
  'Central India': 'inc'
  southindia: 'ins'
  'South India': 'ins'
  westindia: 'inw'
  'West India': 'inw'
  italynorth: 'itn'
  'Italy North': 'itn'
  japaneast: 'jpe'
  'Japan East': 'jpe'
  japanwest: 'jpw'
  'Japan West': 'jpw'
  jioindiacentral: 'jic'
  'Jio India Central': 'jic'
  jioindiawest: 'jiw'
  'Jio India West': 'jiw'
  koreacentral: 'krc'
  'Korea Central': 'krc'
  koreasouth: 'krs'
  'Korea South': 'krs'
  northcentralus: 'ncus'
  'North Central US': 'ncus'
  northeurope: 'ne'
  'North Europe': 'ne'
  norwayeast: 'nwe'
  'Norway East': 'nwe'
  norwaywest: 'nww'
  'Norway West': 'nww'
  qatarcentral: 'qac'
  'Qatar Central': 'qac'
  southafricanorth: 'san'
  'South Africa North': 'san'
  southafricawest: 'saw'
  'South Africa West': 'saw'
  southcentralus: 'scus'
  'South Central US': 'scus'
  swedencentral: 'sdc'
  'Sweden Central': 'sdc'
  swedensouth: 'sds'
  'Sweden South': 'sds'
  southeastasia: 'sea'
  'Southeast Asia': 'sea'
  switzerlandnorth: 'szn'
  'Switzerland North': 'szn'
  switzerlandwest: 'szw'
  'Switzerland West': 'szw'
  uaecentral: 'uac'
  'UAE Central': 'uac'
  uaenorth: 'uan'
  'UAE North': 'uan'
  uksouth: 'uks'
  'UK South': 'uks'
  ukwest: 'ukw'
  'UK West': 'ukw'
  westcentralus: 'wcus'
  'West Central US': 'wcus'
  westeurope: 'we'
  'West Europe': 'we'
  westus: 'wus'
  'West US': 'wus'
  westus2: 'wus2'
  'West US 2': 'wus2'
  westus3: 'wus3'
  'West US 3': 'wus3'
  usdodcentral: 'udc'
  'USDoD Central': 'udc'
  usdodeast: 'ude'
  'USDoD East': 'ude'
  usgovarizona: 'uga'
  'USGov Arizona': 'uga'
  usgoviowa: 'ugi'
  'USGov Iowa': 'ugi'
  usgovtexas: 'ugt'
  'USGov Texas': 'ugt'
  usgovvirginia: 'ugv'
  'USGov Virginia': 'ugv'
  usnateast: 'exe'
  'USNat East': 'exe'
  usnatwest: 'exw'
  'USNat West': 'exw'
  usseceast: 'rxe'
  'USSec East': 'rxe'
  ussecwest: 'rxw'
  'USSec West': 'rxw'
  chinanorth: 'bjb'
  'China North': 'bjb'
  chinanorth2: 'bjb2'
  'China North 2': 'bjb2'
  chinanorth3: 'bjb3'
  'China North 3': 'bjb3'
  chinaeast: 'sha'
  'China East': 'sha'
  chinaeast2: 'sha2'
  'China East 2': 'sha2'
  chinaeast3: 'sha3'
  'China East 3': 'sha3'
  germanycentral: 'gec'
  'Germany Central': 'gec'
  germanynortheast: 'gne'
  'Germany North East': 'gne'
}

var maxLength = Defs[resourceType].maxLength
var lowerCase = Defs[resourceType].lowerCase
// Hyphens (default segment separator) must be removed for certain resource types (storage accounts)
// and might be removed based on parameter input for others
var doRemoveSegmentSeparator = (Defs[resourceType].alwaysRemoveSegmentSeparator || removeSegmentSeparator)

// Translate the regular location value to a shorter value
var shortLocationValue = shortLocations[location]
// Create a two-digit sequence string
var sequenceFormatted = format('{0:00}', sequence)

// Just in case we need them
// For idempotency, deployments of the same type, workload, environment, sequence, and resource group will yield the same resource name
var randomChars = addRandomChars > 0 ? take(uniqueString(subscription().subscriptionId, workloadName, location, environment, string(sequence), resourceType, additionalRandomInitializer), addRandomChars) : ''

// Remove {subWorkloadName} if not needed
var namingConventionSubProcessed = empty(subWorkloadName) ? replace(namingConvention, '-{subWorkloadName}', '') : namingConvention

// Remove segment separators (usually dash/hyphens (-)) from the naming convention if needed
var namingConventionSegmentSeparatorProcessed = doRemoveSegmentSeparator ? replace(namingConventionSubProcessed, segmentSeparator, '') : namingConventionSubProcessed

var workloadNameSegmentSeparatorProcessed = doRemoveSegmentSeparator ? replace(workloadName, segmentSeparator, '') : workloadName
var subWorkloadNameSegmentSeparatorProcessed = doRemoveSegmentSeparator ? replace(subWorkloadName, segmentSeparator, '') : subWorkloadName
var randomizedWorkloadName = '${workloadNameSegmentSeparatorProcessed}${randomChars}'

// Use the naming convention to create two names: one shortened, one regular
var regularName = replace(replace(replace(replace(replace(replace(namingConventionSegmentSeparatorProcessed, '{env}', toLower(environment)), '{loc}', location), '{seq}', sequenceFormatted), '{workloadName}', randomizedWorkloadName), '{rtype}', resourceType), '{subWorkloadName}', subWorkloadNameSegmentSeparatorProcessed)
// The short name uses one character for the environment, a shorter location name, and the minimum number of digits for the sequence
var shortName = replace(replace(replace(replace(replace(replace(namingConventionSegmentSeparatorProcessed, '{env}', toLower(take(environment, 1))), '{loc}', shortLocationValue), '{seq}', string(sequence)), '{workloadName}', randomizedWorkloadName), '{rtype}', resourceType), '{subWorkloadName}', subWorkloadNameSegmentSeparatorProcessed)

// Based on the length of the workload name, the short name could still be too long
var mustTryVowelRemoval = length(shortName) > maxLength
// How many vowels would need to be removed to be effective without further shortening
var minEffectiveVowelRemovalCount = length(shortName) - maxLength

// If allowed, try removing vowels
var workloadNameVowelsProcessed = mustTryVowelRemoval && useRemoveVowelStrategy ? replace(replace(replace(replace(replace(workloadNameSegmentSeparatorProcessed, 'a', ''), 'e', ''), 'i', ''), 'o', ''), 'u', '') : workloadNameSegmentSeparatorProcessed
var subWorkloadNameVowelsProcessed = mustTryVowelRemoval && useRemoveVowelStrategy ? replace(replace(replace(replace(replace(subWorkloadNameSegmentSeparatorProcessed, 'a', ''), 'e', ''), 'i', ''), 'o', ''), 'u', '') : subWorkloadNameSegmentSeparatorProcessed

var mustShortenWorkloadName = (length(randomizedWorkloadName) - length('${workloadNameVowelsProcessed}${randomChars}')) < minEffectiveVowelRemovalCount

// Determine how many characters must be kept from the workload name
var workloadNameCharsToKeep = mustShortenWorkloadName ? length(workloadNameVowelsProcessed) - length(shortName) + maxLength : length(workloadName)

// Create a shortened workload name by removing characters from the end
var shortWorkloadName = '${take(workloadNameVowelsProcessed, workloadNameCharsToKeep)}${randomChars}'

// Recreate a proposed short name for the resource
var actualShortName = replace(replace(replace(replace(replace(replace(namingConventionSegmentSeparatorProcessed, '{env}', toLower(take(environment, 1))), '{loc}', shortLocationValue), '{seq}', string(sequence)), '{workloadName}', shortWorkloadName), '{rtype}', resourceType), '{subWorkloadName}', subWorkloadNameVowelsProcessed)

// The actual name of the resource depends on whether shortening is required or the length of the regular name exceeds the maximum length allowed for the resource type
var actualName = (requireShorten || length(regularName) > maxLength) ? actualShortName : regularName

var actualNameCased = lowerCase ? toLower(actualName) : actualName

// This take() function shouldn't actually remove any characters, just here for safety
output shortName string = take(actualNameCased, maxLength)

// For debugging only
output workloadNameCharsKept int = workloadNameCharsToKeep
output originalShortNameLength int = length(shortName)
output actualNameCased string = actualNameCased
output workloadNameVowelsProcessed string = workloadNameVowelsProcessed
output triedVowelRemoval bool = mustTryVowelRemoval
output minEffectiveVowelRemovalCount int = minEffectiveVowelRemovalCount
