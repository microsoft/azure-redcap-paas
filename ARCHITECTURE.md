# Azure REDCap PaaS - High-Level Architecture

## Overview

This document describes the high-level architecture of the REDCap Platform-as-a-Service (PaaS) deployment on Microsoft Azure. The solution is designed to provide a secure, scalable, and highly available REDCap research data capture environment using Azure managed services.

## Architecture Principles

- **Security First**: All services communicate over private endpoints with no public internet exposure
- **Managed Services**: Leverages Azure PaaS offerings to minimize operational overhead
- **Network Isolation**: Complete network segmentation using Virtual Network and subnets
- **Identity-Based Access**: Uses Managed Identity for secure service-to-service authentication
- **Secrets Management**: All credentials stored in Azure Key Vault with RBAC controls
- **High Availability**: Optional zone-redundant deployments for critical components
- **Compliance Ready**: Supports encryption at rest and in transit

## Components Architecture

### Resource Organization

The deployment creates multiple resource groups organized by workload type:

| Resource Group | Purpose | Key Resources |
|----------------|---------|---------------|
| `{workload}-{env}-rg-network-{seq}` | Networking | Virtual Network, Subnets |
| `{workload}-{env}-rg-storage-{seq}` | Storage | Storage Account, Private Endpoint |
| `{workload}-{env}-rg-database-{seq}` | Database | MySQL Flexible Server, Private DNS |
| `{workload}-{env}-rg-web-{seq}` | Application | App Service, App Service Plan, Managed Identity |
| `{workload}-{env}-rg-monitoring-{seq}` | Observability | Log Analytics, Application Insights |
| `{workload}-{env}-rg-keyVault-{seq}` | Secrets | Key Vault, Private Endpoint |

### Core Components

#### 1. Virtual Network (VNet)
- **Purpose**: Provides network isolation and private connectivity
- **Address Space**: User-defined (minimum /24)
- **Subnets**:
  - **PrivateLinkSubnet** (/27): Hosts private endpoints for PaaS services
  - **ComputeSubnet** (/27): Reserved for compute resources (e.g., AVD, VMs for admin access)
  - **IntegrationSubnet** (/26): App Service VNet integration for outbound traffic
  - **MySQLFlexSubnet** (/29): MySQL Flexible Server delegated subnet

#### 2. App Service (Web Application)
- **Runtime**: Linux with PHP 8.2
- **App Service Plan**: Premium v3 SKU (P0v3 default, configurable)
- **Key Features**:
  - VNet integration for secure outbound connectivity
  - Optional private endpoint for inbound traffic (default: enabled)
  - Managed Identity for Key Vault and MySQL access
  - Application Insights integration for monitoring
  - REDCap deployment automation via Kudu
  - Configurable time zone support
- **Connectivity**:
  - Inbound: Private endpoint (optional) or public
  - Outbound: VNet integration to access private resources
- **Location**: `modules/webapp/main.bicep`

#### 3. MySQL Flexible Server
- **Version**: MySQL 8.0.21
- **Database**: `redcapdb` with utf8 charset (REDCap requirement)
- **SKU**: Configurable (default: Burstable/Standard_B1ms)
- **Storage**: Configurable size and IOPS
- **High Availability**: Optional same-zone or zone-redundant HA
- **Network**: Private access only via delegated subnet
- **Admin Account**: `sqladmin` (configurable)
- **Location**: `modules/sql/main.bicep`

#### 4. Storage Account
- **Type**: StorageV2 with Standard_LRS
- **Container**: `redcap` for REDCap file attachments
- **Access**: Private endpoint only
- **Key Management**: Primary key stored in Key Vault
- **Location**: `modules/storage/main.bicep`

#### 5. Key Vault
- **Purpose**: Centralized secrets management
- **Stored Secrets**:
  - SQL admin username and password
  - REDCap Community credentials
  - Storage account primary key
- **Access Control**: RBAC-based
  - Deployment principal: Key Vault Administrator
  - App Service Managed Identity: Key Vault Secrets User
- **Network**: Private endpoint access
- **Location**: `modules/kv/main.bicep`

#### 6. Monitoring Stack
- **Log Analytics Workspace**: Central log aggregation (PerGB2018 SKU, 30-day retention)
- **Application Insights**: Application performance monitoring and telemetry
- **Location**: `modules/monitoring/main.bicep`

#### 7. User Assigned Managed Identity (UAMI)
- **Purpose**: Provides identity for App Service
- **Permissions**:
  - Key Vault Secrets User (read secrets)
  - MySQL database operations
  - Storage account access
- **Location**: `modules/uami/main.bicep`

#### 8. Private DNS Zones
- **Purpose**: DNS resolution for private endpoints
- **Zones Created**:
  - `privatelink.blob.core.windows.net` (Storage)
  - `privatelink.vaultcore.azure.net` (Key Vault)
  - `privatelink.azurewebsites.net` (App Service)
  - `privatelink.mysql.database.azure.com` (MySQL)
- **Integration**: Linked to VNet for private name resolution
- **Location**: `modules/pdns/main.bicep`

## Network Architecture

### Network Flow Diagram (Conceptual)

```
┌─────────────────────────────────────────────────────────────────┐
│                      Virtual Network                             │
│                    (User-defined CIDR)                           │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ PrivateLinkSubnet (/27)                                    │ │
│  │  • Storage Account Private Endpoint                        │ │
│  │  • Key Vault Private Endpoint                              │ │
│  │  • App Service Private Endpoint (optional)                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ IntegrationSubnet (/26)                                    │ │
│  │  [Delegated to Microsoft.Web/serverFarms]                  │ │
│  │  • App Service VNet Integration                            │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ MySQLFlexSubnet (/29)                                      │ │
│  │  [Delegated to Microsoft.DBforMySQL/flexibleServers]       │ │
│  │  • MySQL Flexible Server                                   │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ ComputeSubnet (/27)                                        │ │
│  │  • Reserved for admin access (AVD, VM + Bastion)           │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Service Endpoints

Each subnet is configured with service endpoints for:
- Microsoft.KeyVault
- Microsoft.Storage
- Microsoft.Web (where applicable)

### Network Security Features

- **Private Endpoints**: All PaaS services accessible only via private IP addresses
- **VNet Integration**: App Service integrates with VNet for outbound connectivity
- **Delegated Subnets**: MySQL and App Service use dedicated delegated subnets
- **Private DNS**: Automatic DNS resolution for private endpoint FQDNs
- **No Public Access**: All resources communicate over private network (when private endpoint enabled)

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Network Isolation                                  │
│  • Private Endpoints                                        │
│  • VNet Integration                                         │
│  • Subnet Delegation                                        │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Identity & Access Management                       │
│  • Managed Identity (UAMI)                                  │
│  • RBAC on Key Vault                                        │
│  • No stored credentials in code                            │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Secrets Management                                 │
│  • Key Vault for all secrets                                │
│  • Key Vault references in App Service                      │
│  • Automatic secret rotation capability                     │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Data Protection                                    │
│  • Encryption at rest (Storage, MySQL)                      │
│  • TLS/HTTPS for all connections                            │
│  • MySQL requires TLS                                       │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Monitoring & Compliance                            │
│  • Application Insights telemetry                           │
│  • Log Analytics for audit logs                             │
│  • Azure Monitor integration                                │
└─────────────────────────────────────────────────────────────┘
```

### Identity and Access

#### Managed Identity Flow
```
App Service (UAMI)
    │
    ├──→ Key Vault (Secrets User)
    │    └──→ Retrieves: DB credentials, storage key
    │
    ├──→ MySQL Server
    │    └──→ Executes: Database operations
    │
    └──→ Storage Account
         └──→ Accesses: Blob containers
```

### Secrets Management

All sensitive data is stored in Azure Key Vault:
- SQL admin username and password
- REDCap Community site credentials
- Storage account access key

App Service retrieves secrets using Key Vault references:
- Format: `@Microsoft.KeyVault(SecretUri=https://{vault}.vault.azure.net/secrets/{secret})`
- Dynamic resolution at runtime
- No secrets stored in application code or configuration

## Data Flow

### REDCap Application Request Flow

```
1. User Request
   │
   ├─→ [Optional] Private Endpoint
   │   └─→ App Service (Web App)
   │       │
   │       ├─→ MySQL Flexible Server
   │       │   └─→ Database operations (via private network)
   │       │
   │       ├─→ Storage Account
   │       │   └─→ File upload/download (via private endpoint)
   │       │
   │       ├─→ Key Vault
   │       │   └─→ Secret retrieval (via Managed Identity)
   │       │
   │       └─→ Application Insights
   │           └─→ Telemetry and logging
   │
   └─→ [OR] Public Endpoint (if private endpoint disabled)
       └─→ App Service (Web App)
```

### REDCap Deployment Flow

```
1. Deployment Initiation
   │
   ├─→ Bicep Deployment
   │   ├─→ Resource Groups created
   │   ├─→ Networking resources
   │   ├─→ MySQL server provisioned
   │   ├─→ Storage account created
   │   ├─→ Key Vault provisioned & secrets stored
   │   └─→ App Service created
   │
   └─→ App Service Configuration
       ├─→ SCM (Kudu) triggered
       ├─→ GitHub repo cloned
       ├─→ startup.sh executed (prerequisites)
       ├─→ deploy.sh executed
       │   ├─→ Downloads REDCap from Community site
       │   ├─→ Extracts to web root
       │   └─→ Configures database connection
       └─→ postbuild.sh executed
           └─→ Initializes database schema
```

### Data Storage Paths

- **Application Files**: App Service file system (`/home/site/wwwroot`)
- **REDCap Attachments**: Azure Blob Storage (`redcap` container)
- **Database**: MySQL Flexible Server (`redcapdb` database)
- **Logs**: Log Analytics Workspace
- **Telemetry**: Application Insights

## High Availability & Disaster Recovery

### High Availability Options

#### MySQL Flexible Server HA
- **Mode**: Same-zone or zone-redundant (configurable via `mySqlHighAvailability`)
- **RTO**: Automatic failover in minutes
- **RPO**: Near-zero (synchronous replication)
- **Configuration**: `main.bicep:59` - `mySqlHighAvailability` parameter

#### App Service Zone Redundancy
- **Mode**: Zone-redundant deployment (configurable via `availabilityZonesEnabled`)
- **Instances**: Automatically spread across availability zones
- **Configuration**: `main.bicep:86` - `availabilityZonesEnabled` parameter

### Backup and Recovery

#### MySQL Backups
- **Automated Backups**: Enabled by default
- **Retention**: 7 days (configurable up to 35 days)
- **Point-in-time Restore**: Supported
- **Geo-redundant Backups**: Available (not enabled by default)

#### Storage Account
- **Redundancy**: LRS (configurable to ZRS, GRS, GZRS)
- **Soft Delete**: Recommended to enable post-deployment
- **Versioning**: Available for blob versioning

### Disaster Recovery Considerations

1. **Cross-Region DR**: Requires manual setup of secondary region deployment
2. **Backup Strategy**:
   - MySQL automated backups
   - Storage account replication (upgrade to GRS/GZRS)
   - Application Insights data retention
3. **Recovery Procedures**: Document manual failover steps for cross-region scenarios

## Scalability

### Vertical Scaling

#### App Service
- **SKU Options**: B1, S1, P1v2, P2v2, P3v2, P0v3-P3v3
- **Configuration**: `main.bicep:83` - `appServiceSkuName` parameter
- **Scaling**: Can scale up/down without downtime

#### MySQL Flexible Server
- **SKU Options**: Burstable (B1ms, B2s), GeneralPurpose (D-series), MemoryOptimized (E-series)
- **Configuration**:
  - `main.bicep:61` - `mySqlSkuName` parameter
  - `main.bicep:68` - `mySqlSkuTier` parameter
- **Storage**: Can scale up (not down)

### Horizontal Scaling

#### App Service
- **Auto-scale**: Configure scale rules based on:
  - CPU percentage
  - Memory percentage
  - Request count
  - Custom metrics from Application Insights
- **Manual Scale Out**: Increase instance count
- **Zone Redundancy**: Automatically distributes across zones when enabled

### Performance Optimization

- **Application Insights**: Monitor performance bottlenecks
- **MySQL Indexing**: Optimize database queries
- **Storage IOPS**: Increase for better throughput
- **CDN**: Consider Azure CDN for static assets
- **Caching**: Implement Redis Cache for session state

## Monitoring and Observability

### Application Insights

- **Telemetry Data**:
  - Request rates and response times
  - Failed requests
  - Dependency tracking (MySQL, Storage)
  - Custom events and metrics
- **Integration**: Native integration with App Service
- **Alerts**: Configure alerts on metrics and anomalies

### Log Analytics

- **Centralized Logging**: Aggregates logs from all resources
- **Retention**: 30 days (configurable)
- **Query Language**: KQL (Kusto Query Language)
- **Workbooks**: Create custom dashboards

### Monitoring Dashboard

Recommended metrics to monitor:
- App Service: CPU %, Memory %, Response Time, HTTP 5xx errors
- MySQL: CPU %, Memory %, Connections, Replication lag (if HA enabled)
- Storage: Availability, Latency, Transactions
- Key Vault: Access success rate, latency

## Integration Options

### Existing Network Integration

The deployment supports integration with existing Azure infrastructure:

#### Bring Your Own VNet
- **Parameter**: `existingVirtualNetworkId` (`main.bicep:88`)
- **Requirements**:
  - Subnets must be pre-created with matching names
  - Sufficient address space for subnet requirements
  - Subnet delegation configured appropriately

#### Bring Your Own Private DNS Zones
- **Parameter**: `existingPrivateDnsZonesResourceGroupId` (`main.bicep:87`)
- **Requirements**:
  - Private DNS zones must exist for all services
  - DNS zones must be linked to target VNet

### SMTP Configuration

Email functionality via external SMTP relay:
- **Parameters**:
  - `smtpFQDN` - SMTP server address
  - `smtpPort` - SMTP port (25, 587, etc.)
  - `smtpFromEmailAddress` - Sender email address
- **Supported Services**: Exchange Online, SendGrid, custom SMTP servers

## Cost Optimization

### Cost Drivers

1. **App Service Plan**: Primary cost driver (Premium SKU)
2. **MySQL Flexible Server**: Compute (SKU) + Storage + IOPS
3. **Storage Account**: Storage capacity + transactions
4. **Log Analytics**: Data ingestion and retention
5. **High Availability**: Additional cost for HA-enabled MySQL

### Cost Optimization Strategies

- **Right-sizing**: Start with smaller SKUs and scale as needed
- **Auto-scale**: Configure scale-in rules to reduce instances during low usage
- **Reserved Instances**: Purchase 1-year or 3-year reservations for predictable workloads
- **Log Retention**: Adjust retention period based on compliance requirements
- **Storage Tiers**: Use cool/archive tiers for older data
- **Development/Test Environments**: Use lower-tier SKUs for non-production

## Deployment Customization

### Key Parameters

| Parameter | Default | Purpose | Location |
|-----------|---------|---------|----------|
| `location` | eastus | Azure region | `main.bicep:4` |
| `environment` | demo | Environment name | `main.bicep:12` |
| `vnetAddressSpace` | - | VNet CIDR (min /24) | `main.bicep:26` |
| `mySqlHighAvailability` | Disabled | Enable MySQL HA | `main.bicep:59` |
| `mySqlSkuName` | Standard_B1ms | MySQL SKU | `main.bicep:61` |
| `appServiceSkuName` | P0v3 | App Service SKU | `main.bicep:83` |
| `availabilityZonesEnabled` | false | Zone redundancy | `main.bicep:86` |
| `enableAppServicePrivateEndpoint` | true | Private endpoint | `main.bicep:48` |

### Deployment Modes

#### Development/Test
```bicep
environment: 'dev'
mySqlSkuName: 'Standard_B1ms'
appServiceSkuName: 'B1'
mySqlHighAvailability: 'Disabled'
availabilityZonesEnabled: false
```

#### Production
```bicep
environment: 'prod'
mySqlSkuName: 'Standard_D4ds_v4'
appServiceSkuName: 'P2v3'
mySqlHighAvailability: 'Enabled'
availabilityZonesEnabled: true
```

## Security Considerations

### Post-Deployment Hardening

1. **Remove REDCap Community Credentials**: Delete from App Service configuration after deployment
2. **Enable Diagnostic Logging**: Configure diagnostic settings for all resources
3. **Configure Alerts**: Set up alerts for security and availability events
4. **Review NSG Rules**: If using existing VNet, verify Network Security Groups
5. **Enable Advanced Threat Protection**: For Storage and MySQL
6. **Implement Backup Strategy**: Configure backup policies
7. **TLS Configuration**: Ensure minimum TLS 1.2 for all services
8. **Custom Domain**: Configure custom domain and SSL certificate for App Service

### Compliance

The architecture supports compliance frameworks:
- **HIPAA**: Enable additional encryption and logging features
- **GDPR**: Configure data retention and deletion policies
- **SOC 2**: Enable audit logging and monitoring
- **FedRAMP**: Deploy in Azure Government regions (requires adjustments)

## Known Limitations

1. **REDCap Easy Upgrade**: Not supported in Azure deployments (as of documentation date)
2. **NFS Storage**: Older REDCap versions may require manual NFS provisioning
3. **Database CLI Access**: Requires VM/AVD deployment in VNet for MySQL client access
4. **Regional Availability**: Zone redundancy requires region support for availability zones
5. **MySQL Version**: Limited to MySQL 8.0.21 in current configuration

## Future Enhancements

Potential improvements to consider:
- **Azure Front Door**: Global load balancing and WAF
- **Azure DDoS Protection**: Enhanced DDoS mitigation
- **Azure Backup**: Centralized backup management
- **Azure Site Recovery**: Automated disaster recovery
- **Container Support**: Migrate to containerized deployment (App Service Container or AKS)
- **DevOps Integration**: CI/CD pipelines for infrastructure and application updates

## References

- Main Bicep Template: `main.bicep`
- Networking Module: `modules/networking/main.bicep`
- MySQL Module: `modules/sql/main.bicep`
- Web App Module: `modules/webapp/main.bicep`
- Storage Module: `modules/storage/main.bicep`
- Key Vault Module: `modules/kv/main.bicep`
- Monitoring Module: `modules/monitoring/main.bicep`

## Support

For issues, questions, or contributions, please refer to the [README.md](README.md) and [SECURITY.md](SECURITY.md) documentation.
