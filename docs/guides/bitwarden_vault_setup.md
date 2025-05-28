# Bitwarden Vault Setup Guide

**Last Updated:** 2025-05-28  
**Status:** Complete - All methods tested and validated  
**Maintainer:** Auth-DDF Team  

This guide explains how to set up the required Bitwarden vault structure for the Auth-DDF project's credential sync functionality.

## Overview

The Auth-DDF project uses Bitwarden for secure credential management and automated environment setup. The sync script (`scripts/local/bitwarden-sync.sh`) expects specific vault items with predefined field structures.

## Required Vault Items

### 1. AWS Credentials (`auth-ddf-aws`)

**Item Type:** Secure Note  
**Purpose:** AWS deployment credentials for development environment  

**Required Fields:**
- `access_key_id` (Text) → Maps to `AWS_ACCESS_KEY_ID`
- `secret_access_key` (Hidden) → Maps to `AWS_SECRET_ACCESS_KEY`

**Example Values:**
- `access_key_id`: `AKIA...EXAMPLE` (replace with your actual AWS access key)
- `secret_access_key`: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` (replace with your actual secret key)

### 2. Local PostgreSQL Credentials (`auth-ddf-postgres`)

**Item Type:** Secure Note  
**Purpose:** Database credentials for local development environment  

**Required Fields:**
- `password` (Hidden) → Maps to `DATABASE_PASSWORD_LOCAL`

**Example Values:**
- `password`: `dev-password`

### 3. AWS PostgreSQL Credentials (`postgres-dataapps`) - **EXISTING NOTE**

**Item Type:** Secure Note  
**Purpose:** AWS PostgreSQL database credentials (already exists)  
**Status:** ✅ **Already exists - no action needed**

**Expected JSON Format in Notes field:**
```json
{
  "host": "your-aws-postgres-host.amazonaws.com",
  "port": "5432",
  "database": "your_database_name",
  "username": "your_username",
  "password": "your_password"
}
```

**Maps to Environment Variables:**
- `host` → `POSTGRES_HOST_AWS`
- `port` → `POSTGRES_PORT_AWS`
- `database` → `POSTGRES_DB_AWS`
- `username` → `POSTGRES_USER_AWS`
- `password` → `DATABASE_PASSWORD_AWS`

### 4. Keycloak Credentials (`auth-ddf-keycloak`)

**Item Type:** Secure Note  
**Purpose:** Keycloak admin credentials for authentication server management  

**Required Fields:**
- `admin_password` (Hidden) → Maps to `KEYCLOAK_ADMIN_PASSWORD`

**Example Values:**
- `admin_password`: `admin`

## Vault Structure Summary

| Item Name | Type | Purpose | Status |
|-----------|------|---------|--------|
| `postgres-dataapps` | Note | AWS PostgreSQL credentials | ✅ **Existing** |
| `auth-ddf-aws` | Secure Note | AWS access credentials | ❌ **Needs Creation** |
| `auth-ddf-postgres` | Secure Note | Local PostgreSQL credentials | ❌ **Needs Creation** |
| `auth-ddf-keycloak` | Secure Note | Keycloak admin credentials | ❌ **Needs Creation** |

## Setup Methods

### Method 1: Automated Creation (Recommended)

Use the provided script to automatically create the missing vault items:

```bash
# Test what would be created (dry-run)
./scripts/local/create-bitwarden-items.sh --env=dev --dry-run --verbose

# Create the missing items
./scripts/local/create-bitwarden-items.sh --env=dev

# Force recreate if items already exist
./scripts/local/create-bitwarden-items.sh --env=dev --force
```

**Prerequisites:**
- Bitwarden CLI installed (`npm install -g @bitwarden/cli`)
- `jq` installed (`brew install jq` on macOS)
- Valid Bitwarden credentials in `.env` file
- **`postgres-dataapps` note already exists** (verified automatically)

### Method 2: Manual Creation via Web Interface (Recommended for CLI Issues)

**When to use:** If you're experiencing Bitwarden CLI authentication issues or prefer a visual interface.

#### Step 1: Access Bitwarden Web Vault
1. Go to [https://vault.bitwarden.com](https://vault.bitwarden.com)
2. Login with your credentials
3. Ensure you're in the appropriate organization vault (check the organization selector in the top-left)

#### Step 2: Verify Existing Items

**Check for `postgres-dataapps`:**
- Use the search box to find "postgres-dataapps"
- Should already exist as a Secure Note
- Contains AWS PostgreSQL credentials in JSON format
- **Important: Do not modify this existing note**

#### Step 3: Create Missing Items

For each required item, follow these steps:

1. Click **"New Item"**
2. Select **"Secure Note"** as item type
3. Fill in the details as specified below:

**For `auth-ddf-aws`:**
- **Name:** `auth-ddf-aws`
- **Notes:** `AWS credentials for Auth-DDF development environment`
- **Custom Fields:**
  - Add field: `access_key_id` (Text) = `your-actual-aws-access-key`
  - Add field: `secret_access_key` (Hidden) = `your-actual-aws-secret-key`
- Click **"Save"**

**For `auth-ddf-postgres`:**
- **Name:** `auth-ddf-postgres`
- **Notes:** `Local PostgreSQL credentials for Auth-DDF development environment`
- **Custom Fields:**
  - Add field: `password` (Hidden) = `dev-password`
- Click **"Save"**

**For `auth-ddf-keycloak`:**
- **Name:** `auth-ddf-keycloak`
- **Notes:** `Keycloak admin credentials for Auth-DDF development environment`
- **Custom Fields:**
  - Add field: `admin_password` (Hidden) = `admin`
- Click **"Save"**

#### Step 4: Verify Items Were Created

1. Use the search box to verify all items exist:
   - `auth-ddf-aws`
   - `auth-ddf-postgres`
   - `auth-ddf-keycloak`
   - `postgres-dataapps` (should already exist)

2. Verify each item has the correct field structure:
   - `auth-ddf-aws`: Should have `access_key_id` and `secret_access_key` fields
   - `auth-ddf-postgres`: Should have `password` field
   - `auth-ddf-keycloak`: Should have `admin_password` field

### Method 3: Manual Creation via CLI

#### Step 1: Login to Bitwarden
```bash
# Set environment variables
source .env
export BW_CLIENTID="$BITWARDEN_CLIENT_ID"
export BW_CLIENTSECRET="$BITWARDEN_CLIENT_SECRET"

# Login and unlock
bw login --apikey
echo "$BITWARDEN_MASTER_PASSWORD" | bw unlock --raw
```

#### Step 2: Verify Existing postgres-dataapps Note
```bash
# Check if postgres-dataapps note exists
bw get notes "postgres-dataapps"

# Should return JSON with PostgreSQL connection details
```

#### Step 3: Create AWS Credentials Item
```bash
bw create item --template '{
  "type": 2,
  "name": "auth-ddf-aws",
  "notes": "AWS credentials for Auth-DDF development environment",
  "fields": [
    {
      "name": "access_key_id",
      "value": "AKIA...EXAMPLE",
      "type": 0
    },
    {
      "name": "secret_access_key",
      "value": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
      "type": 1
    }
  ]
}'
```

#### Step 4: Create Local PostgreSQL Credentials Item
```bash
bw create item --template '{
  "type": 2,
  "name": "auth-ddf-postgres",
  "notes": "Local PostgreSQL credentials for Auth-DDF development environment",
  "fields": [
    {
      "name": "password",
      "value": "dev-password",
      "type": 1
    }
  ]
}'
```

#### Step 5: Create Keycloak Credentials Item
```bash
bw create item --template '{
  "type": 2,
  "name": "auth-ddf-keycloak",
  "notes": "Keycloak admin credentials for Auth-DDF development environment",
  "fields": [
    {
      "name": "admin_password",
      "value": "admin",
      "type": 1
    }
  ]
}'
```

## Testing and Validation

### Step 1: Test Credential Sync

After creating the vault items, test the credential sync:

```bash
# Source your .env file first (in case AWS credentials are needed)
source .env

# Unlock Bitwarden (you'll need to enter your master password)
bw unlock

# Export the session key (replace with your actual session key)
export BW_SESSION="your-session-key-from-unlock"

# Run the sync script
./scripts/local/bitwarden-sync.sh --env=dev

# Verify the environment file was created
cat .env.dev
```

### Step 2: Validate Application Startup

```bash
# Start your application with the synced credentials
docker-compose up -d

# Verify all services start properly
docker-compose ps

# Check for any errors in logs
docker-compose logs --tail 50
```

## Troubleshooting

### Master Password Issues

If you're having trouble with the Bitwarden master password:

1. **Try logging out and back in to Bitwarden:**
   ```bash
   bw logout
   bw login
   ```

2. **Check organization permissions:** If you're using Bitwarden Organizations, make sure you have the correct permissions to access the items.

3. **Special characters:** Check if any special characters in the master password are causing issues.

4. **Browser extension verification:** Try using the Bitwarden browser extension to verify your credentials work.

### Bitwarden API Issues

If you're having trouble with the Bitwarden API:

1. **Verify API credentials** in the `.env` file:
   ```
   BITWARDEN_CLIENT_ID=your-client-id
   BITWARDEN_CLIENT_SECRET=your-client-secret
   BITWARDEN_MASTER_PASSWORD=your-master-password
   ```

2. **Enable API access:** Check if you need to enable API access in your Bitwarden account settings.

3. **Personal vs Organization API keys:** Consider using personal API keys instead of organization API keys if available.

### Sync Script Issues

If the sync script is failing even after creating the vault items:

1. **Run with verbose output:**
   ```bash
   ./scripts/local/bitwarden-sync.sh --env=dev --verbose
   ```

2. **Check session validity:**
   ```bash
   bw status
   ```

3. **Verify field names:** Ensure field names exactly match what the script expects (case sensitive).

4. **Check item types:** Verify all items are created as "Secure Note" type.

### Common Error Messages

**"Invalid master password"**
- Try unlocking manually: `bw unlock`
- Check for special characters in password
- Verify you're using the correct master password

**"Item not found"**
- Verify item names are exactly: `auth-ddf-aws`, `auth-ddf-postgres`, `auth-ddf-keycloak`
- Check if you're in the correct organization vault
- Ensure items are created as "Secure Note" type

**"Field not found"**
- Verify custom field names match exactly (case sensitive)
- Check field types: Text for `access_key_id`, Hidden for passwords
- Ensure fields are added as "Custom Fields" not in the Notes section

## Security Considerations

### Credential Management
- **Never commit credentials to version control**
- **Use environment-specific credentials** (dev/staging/prod)
- **Rotate credentials regularly** (monthly for development, quarterly for production)
- **Use least-privilege access** for AWS credentials

### Bitwarden Security
- **Enable two-factor authentication** on your Bitwarden account
- **Use strong master password** with high entropy
- **Regularly audit vault access** and permissions
- **Monitor vault activity** through Bitwarden's event logs

### Environment Isolation
- **Separate credentials per environment** (dev/staging/prod)
- **Use different AWS accounts** for different environments when possible
- **Implement proper network isolation** between environments
- **Regular security audits** of credential usage

## Next Steps

After successfully creating all required vault items:

1. **Sync credentials to environment files:**
   ```bash
   ./scripts/local/bitwarden-sync.sh --env=dev
   ```

2. **Start your application with the synced credentials:**
   ```bash
   docker-compose up -d
   ```

3. **Verify all services start properly** with the synced credentials.

4. **Set up automated credential rotation** for production environments.

5. **Document any environment-specific variations** in credential structure.

---

**Related Documentation:**
- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [Auth-DDF Credential Sync Script](../../scripts/local/bitwarden-sync.sh)
- [Environment Configuration Guide](./environment_configuration.md)

**Support:**
- For Bitwarden issues: [Bitwarden Support](https://bitwarden.com/contact/)
- For Auth-DDF issues: Create an issue in the project repository 