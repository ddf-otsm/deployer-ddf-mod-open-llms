# Cursor Chat Export Guide

**Guide Version:** 1.0  
**Created:** 2025-05-27  
**Purpose:** Export and analyze Cursor chat conversations for AWS resource discovery  
**Repository:** deployer-ddf-mod-llm-models

## 📋 **OVERVIEW**

This guide provides a comprehensive solution to export all Cursor chat conversations to organized folders. Cursor stores chat history locally in SQLite databases, and this process extracts, processes, and analyzes the conversations for AWS resource information.

## 🎯 **USE CASES**

- **AWS Resource Discovery**: Find specific resource IDs, ARNs, and stack names from deployment conversations
- **Project Documentation**: Archive important technical discussions and decisions
- **Knowledge Management**: Search through historical conversations for specific information
- **Audit Trail**: Maintain records of infrastructure changes and deployments

## 🔍 **HOW CURSOR STORES CHAT DATA**

Cursor stores chat conversations in a SQLite database located at:
```
~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
```

The conversations are stored in the `cursorDiskKV` table with keys like `composerData:*` containing JSON data with:
- Conversation messages
- Timestamps
- Context information
- Rich text formatting

## 🛠️ **EXPORT PROCESS**

### **Step 1: Database Discovery**

First, locate the Cursor database:
```bash
find ~/Library -name "*cursor*" -type d 2>/dev/null | head -10
ls -la "/Users/luismartins/Library/Application Support/Cursor/"
```

### **Step 2: Database Exploration**

Understand the database structure:
```bash
bash scripts/export/explore-cursor-db.sh
```

This script will:
- Show database size and table structure
- Identify conversation-related tables
- Display sample data to understand format

### **Step 3: Safe Export**

Export conversations using the safe method (works while Cursor is running):
```bash
bash scripts/export/cursor-conversations-export-safe.sh
```

**Why "Safe" Export?**
- Creates a database copy to avoid locking issues
- Works while Cursor is actively running
- Prevents data corruption during export

### **Step 4: AWS Resource Analysis**

Search for AWS resources in exported conversations:
```bash
bash scripts/export/search-aws-resources.sh
```

## 📁 **OUTPUT STRUCTURE**

The export creates a comprehensive directory structure:

```
export/cursor-conversations/
├── README.md                    # Complete usage guide
├── all_conversations.json       # Complete conversation data
├── process_conversations.py     # Processing script
├── conversations/               # Individual conversation files
│   ├── YYYYMMDD_HHMMSS_<id>.json  # Structured data format
│   └── YYYYMMDD_HHMMSS_<id>.md    # Human-readable format
├── summary/                     # Export statistics
│   ├── export_summary.json
│   └── export_summary.md
└── raw/                        # Raw database exports
    └── state_copy_<timestamp>.vscdb
```

## 🔍 **SEARCHING EXPORTED DATA**

### **Basic Search Commands**

```bash
# Search for AWS ARNs
grep -r "arn:aws" ./export/cursor-conversations/conversations/

# Search for specific resources
grep -r "deployer-ddf" ./export/cursor-conversations/conversations/

# Search for stack names
grep -r "stack-name\|StackName" ./export/cursor-conversations/conversations/
```

### **Using the Search Tool**

```bash
# Comprehensive AWS resource search
bash scripts/export/search-aws-resources.sh

# Search for specific terms
bash scripts/export/search-aws-resources.sh "your-search-term"
```

## 📊 **TYPICAL EXPORT RESULTS**

Based on a real export:
- **Total Conversations**: ~288 found
- **Conversations with Content**: ~194 (67%)
- **Export Size**: ~27MB JSON data
- **File Count**: ~388 individual files (JSON + Markdown)
- **Processing Time**: ~30 seconds

## 🔍 **AWS RESOURCE DISCOVERY**

### **Common Resource Patterns Found**

**IAM Roles:**
```
arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-execution-role
arn:aws:iam::ACCOUNT:role/deployer-ddf-mod-llm-models-{environment}-task-role
```

**CloudFormation Stacks:**
```
deployer-ddf-llm-dev
deployer-ddf-llm-prod
```

**ECS Resources:**
```
deployer-ddf-llm-cluster-dev
deployer-ddf-llm-cluster-prod
```

**S3 Buckets:**
```
deployer-ddf-llm-results-dev-{AccountId}
deployer-ddf-llm-results-prod-{AccountId}
```

### **Resource Discovery Commands**

After export, use these commands to find specific AWS resources:

```bash
# CloudFormation stacks
aws cloudformation list-stacks --region us-east-1

# ECS clusters
aws ecs list-clusters --region us-east-1

# S3 buckets
aws s3 ls | grep deployer-ddf-llm-results

# IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `deployer-ddf-mod-llm-models`)]'
```

## 🚨 **TROUBLESHOOTING**

### **Database Locked Error**
```
Error: in prepare, database is locked (5)
```
**Solution**: Use the safe export script which creates a database copy.

### **No Conversations Found**
**Possible Causes**:
- Cursor hasn't been used for chat
- Database location changed
- Permissions issues

**Solution**: Verify database location and permissions.

### **Export Fails**
**Common Issues**:
- Insufficient disk space
- Python not available
- SQLite3 not installed

**Solutions**:
```bash
# Install SQLite3 (macOS)
brew install sqlite3

# Check Python availability
python3 --version

# Check disk space
df -h
```

## 🔧 **CUSTOMIZATION**

### **Custom Export Directory**
```bash
bash scripts/export/cursor-conversations-export-safe.sh --output-dir /custom/path
```

### **Custom Search Patterns**
Edit `scripts/export/search-aws-resources.sh` to add your own search patterns:
```bash
search_and_display "your-pattern" "Your Description"
```

### **Processing Script Modifications**
The Python processing script can be customized to:
- Filter conversations by date range
- Extract specific data fields
- Generate custom reports
- Export to different formats

## 📋 **BEST PRACTICES**

1. **Regular Exports**: Run exports periodically to capture new conversations
2. **Backup Database**: Keep copies of the original database
3. **Organize Results**: Use date-based directories for multiple exports
4. **Security**: Be careful with exported data containing sensitive information
5. **Cleanup**: Remove old exports to save disk space

## 🔗 **RELATED TOOLS**

- **Database Browser**: Use DB Browser for SQLite to manually explore the database
- **JSON Processors**: Use `jq` for advanced JSON processing
- **Text Search**: Use `ripgrep` for faster text searching
- **AWS CLI**: For verifying discovered resources

## 📝 **EXAMPLE WORKFLOW**

```bash
# 1. Export conversations
bash scripts/export/cursor-conversations-export-safe.sh

# 2. Search for AWS resources
bash scripts/export/search-aws-resources.sh

# 3. Find specific deployment info
grep -r "CloudFormation\|deploy" ./export/cursor-conversations/conversations/

# 4. Verify resources in AWS
aws cloudformation list-stacks --region us-east-1

# 5. Document findings
echo "Found resources:" > aws-resources-found.txt
grep -r "arn:aws" ./export/cursor-conversations/conversations/ >> aws-resources-found.txt
```

## ⚠️ **SECURITY CONSIDERATIONS**

- **Sensitive Data**: Exported conversations may contain API keys, passwords, or other sensitive information
- **Access Control**: Limit access to exported data
- **Cleanup**: Securely delete exports when no longer needed
- **Sharing**: Be cautious when sharing exported conversations

## 🎯 **SUCCESS METRICS**

A successful export should provide:
- ✅ Complete conversation history
- ✅ Searchable AWS resource information
- ✅ Organized file structure
- ✅ Summary statistics
- ✅ Easy-to-use search tools

## 🔗 **RELATED DOCUMENTATION**

- **AWS Resources Analysis**: `docs/config/aws-resources-analysis.md`
- **Export Scripts**: `scripts/export/`
- **Deployment Guides**: `docs/deployment/`

This guide enables you to effectively extract, organize, and analyze your Cursor chat history for AWS resource discovery and project documentation purposes. 