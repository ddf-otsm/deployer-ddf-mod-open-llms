#!/bin/bash

# Cursor Conversations Export Script (Safe Version)
# Works with a copy of the database to avoid locking issues
# Usage: bash scripts/export/cursor-conversations-export-safe.sh [--output-dir DIR]

set -euo pipefail

# Default configuration
CURSOR_DB="/Users/luismartins/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
OUTPUT_DIR="./export/cursor-conversations"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [--output-dir DIR]"
            echo "  --output-dir: Directory to export conversations (default: ./export/cursor-conversations)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create output directory structure
mkdir -p "$OUTPUT_DIR"/{raw,conversations,by-date,summary}

echo "🚀 Starting Cursor Conversations Export (Safe Mode)..."
echo "📁 Output Directory: $OUTPUT_DIR"
echo "⏰ Timestamp: $TIMESTAMP"

# Check if database exists
if [[ ! -f "$CURSOR_DB" ]]; then
    echo "❌ Cursor database not found at: $CURSOR_DB"
    exit 1
fi

echo "✅ Found Cursor database: $CURSOR_DB"
echo "📊 Database size: $(du -h "$CURSOR_DB" | cut -f1)"

# Create a copy to work with
DB_COPY="$OUTPUT_DIR/raw/state_copy_$TIMESTAMP.vscdb"
echo "📋 Creating database copy..."
cp "$CURSOR_DB" "$DB_COPY"
echo "✅ Database copy created: $DB_COPY"

# Count conversations
CONV_COUNT=$(sqlite3 "$DB_COPY" "SELECT COUNT(*) FROM cursorDiskKV WHERE key LIKE 'composerData:%';" 2>/dev/null || echo "0")
echo "✅ Found $CONV_COUNT conversations"

# Create Python script to process conversations
cat > "$OUTPUT_DIR/process_conversations.py" << 'EOF'
import json
import sqlite3
import os
import sys
from datetime import datetime
import re

def extract_conversations(db_path, output_dir):
    """Extract and process Cursor conversations"""
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get all composer data
        cursor.execute("SELECT key, value FROM cursorDiskKV WHERE key LIKE 'composerData:%'")
        rows = cursor.fetchall()
        
        conversations = []
        processed_count = 0
        
        print(f"Processing {len(rows)} conversation records...")
        
        for key, value in rows:
            try:
                # Parse the JSON value
                data = json.loads(value)
                
                # Extract conversation info
                composer_id = key.replace('composerData:', '')
                conversation = data.get('conversation', [])
                created_at = data.get('createdAt', 0)
                text = data.get('text', '')
                rich_text = data.get('richText', '')
                status = data.get('status', 'unknown')
                context = data.get('context', {})
                
                # Convert timestamp
                if created_at:
                    try:
                        created_date = datetime.fromtimestamp(created_at / 1000)
                    except:
                        created_date = datetime.now()
                else:
                    created_date = datetime.now()
                
                conv_data = {
                    'id': composer_id,
                    'created_at': created_at,
                    'created_date': created_date.isoformat(),
                    'text': text,
                    'rich_text': rich_text,
                    'status': status,
                    'conversation': conversation,
                    'context': context,
                    'message_count': len(conversation),
                    'has_content': bool(conversation or text or rich_text)
                }
                
                conversations.append(conv_data)
                processed_count += 1
                
                # Save individual conversation if it has content
                if conv_data['has_content']:
                    filename = f"{created_date.strftime('%Y%m%d_%H%M%S')}_{composer_id[:8]}.json"
                    filepath = os.path.join(output_dir, 'conversations', filename)
                    with open(filepath, 'w') as f:
                        json.dump(conv_data, f, indent=2)
                    
                    # Create markdown version
                    md_filename = f"{created_date.strftime('%Y%m%d_%H%M%S')}_{composer_id[:8]}.md"
                    md_filepath = os.path.join(output_dir, 'conversations', md_filename)
                    create_markdown_conversation(conv_data, md_filepath)
            
            except Exception as e:
                print(f"Error processing conversation {key}: {e}")
        
        conn.close()
        
        # Save all conversations summary
        with open(os.path.join(output_dir, 'all_conversations.json'), 'w') as f:
            json.dump(conversations, f, indent=2)
        
        # Create summary statistics
        create_summary_report(conversations, output_dir)
        
        print(f"✅ Processed {processed_count} conversations")
        print(f"✅ Found {len([c for c in conversations if c['has_content']])} conversations with content")
        
        return conversations
        
    except Exception as e:
        print(f"❌ Error accessing database: {e}")
        return []

def create_markdown_conversation(conv_data, filepath):
    """Create a markdown file for a conversation"""
    
    with open(filepath, 'w') as f:
        f.write(f"# Conversation {conv_data['id'][:8]}\n\n")
        f.write(f"**Created:** {conv_data['created_date']}\n")
        f.write(f"**Status:** {conv_data['status']}\n")
        f.write(f"**Messages:** {conv_data['message_count']}\n")
        f.write(f"**ID:** {conv_data['id']}\n\n")
        
        if conv_data['text']:
            f.write(f"## Initial Text\n\n{conv_data['text']}\n\n")
        
        if conv_data['rich_text']:
            f.write(f"## Rich Text\n\n{conv_data['rich_text']}\n\n")
        
        if conv_data['conversation']:
            f.write(f"## Conversation\n\n")
            for i, message in enumerate(conv_data['conversation']):
                if isinstance(message, dict):
                    role = message.get('role', 'unknown')
                    content = message.get('content', message.get('text', str(message)))
                    timestamp = message.get('timestamp', '')
                    
                    f.write(f"### Message {i+1} ({role})\n\n")
                    if timestamp:
                        f.write(f"*Timestamp: {timestamp}*\n\n")
                    f.write(f"{content}\n\n")
                else:
                    f.write(f"### Message {i+1}\n\n")
                    f.write(f"{str(message)}\n\n")
        
        # Add context information if available
        if conv_data['context']:
            f.write(f"## Context\n\n")
            f.write(f"```json\n{json.dumps(conv_data['context'], indent=2)}\n```\n\n")

def create_summary_report(conversations, output_dir):
    """Create a summary report of all conversations"""
    
    total_conversations = len(conversations)
    conversations_with_content = [c for c in conversations if c['has_content']]
    total_messages = sum(c['message_count'] for c in conversations)
    
    # Group by date
    by_date = {}
    for conv in conversations_with_content:
        date = conv['created_date'][:10]  # YYYY-MM-DD
        if date not in by_date:
            by_date[date] = []
        by_date[date].append(conv)
    
    # Create summary
    summary = {
        'export_date': datetime.now().isoformat(),
        'total_conversations': total_conversations,
        'conversations_with_content': len(conversations_with_content),
        'total_messages': total_messages,
        'date_range': {
            'earliest': min(c['created_date'] for c in conversations_with_content) if conversations_with_content else None,
            'latest': max(c['created_date'] for c in conversations_with_content) if conversations_with_content else None
        },
        'by_date': {date: len(convs) for date, convs in by_date.items()}
    }
    
    # Save summary
    with open(os.path.join(output_dir, 'summary', 'export_summary.json'), 'w') as f:
        json.dump(summary, f, indent=2)
    
    # Create markdown summary
    with open(os.path.join(output_dir, 'summary', 'export_summary.md'), 'w') as f:
        f.write("# Cursor Conversations Export Summary\n\n")
        f.write(f"**Export Date:** {summary['export_date']}\n\n")
        f.write(f"**Total Conversations:** {summary['total_conversations']}\n")
        f.write(f"**Conversations with Content:** {summary['conversations_with_content']}\n")
        f.write(f"**Total Messages:** {summary['total_messages']}\n\n")
        
        if summary['date_range']['earliest']:
            f.write(f"**Date Range:** {summary['date_range']['earliest']} to {summary['date_range']['latest']}\n\n")
        
        f.write("## Conversations by Date\n\n")
        for date, count in sorted(summary['by_date'].items()):
            f.write(f"- **{date}:** {count} conversations\n")
        
        f.write("\n## Files Created\n\n")
        f.write("- `all_conversations.json` - Complete conversation data\n")
        f.write("- `conversations/*.json` - Individual conversation files\n")
        f.write("- `conversations/*.md` - Markdown versions of conversations\n")
        f.write("- `summary/export_summary.json` - This summary in JSON format\n")

if __name__ == "__main__":
    db_path = sys.argv[1] if len(sys.argv) > 1 else "./export/cursor-conversations/raw/state_copy.vscdb"
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "./export/cursor-conversations"
    
    conversations = extract_conversations(db_path, output_dir)
EOF

# Run the processing script
echo "🔄 Processing conversations..."
python3 "$OUTPUT_DIR/process_conversations.py" "$DB_COPY" "$OUTPUT_DIR"

# Create final summary
echo ""
echo "📊 Creating final summary..."
cat > "$OUTPUT_DIR/README.md" << EOF
# Cursor Conversations Export

**Export Date:** $(date)
**Source Database:** $CURSOR_DB
**Database Copy:** $DB_COPY
**Total Conversations Found:** $CONV_COUNT

## Directory Structure

\`\`\`
$OUTPUT_DIR/
├── README.md                    # This file
├── all_conversations.json       # Complete conversation data
├── process_conversations.py     # Processing script
├── conversations/               # Individual conversation files
│   ├── *.json                  # JSON format
│   └── *.md                    # Markdown format
├── summary/                     # Summary reports
│   ├── export_summary.json
│   └── export_summary.md
└── raw/                        # Raw database exports
    └── state_copy_$TIMESTAMP.vscdb
\`\`\`

## Usage

1. **Browse conversations:** Check the \`conversations/\` directory
2. **View summary:** Open \`summary/export_summary.md\`
3. **Process data:** Use \`all_conversations.json\` for analysis
4. **Re-run export:** \`bash scripts/export/cursor-conversations-export-safe.sh\`

## Finding Specific Conversations

- Files are named by date: \`YYYYMMDD_HHMMSS_<id>.md\`
- Check \`summary/export_summary.md\` for date-based grouping
- Search in \`all_conversations.json\` for specific content

## AWS Resource Analysis

To find AWS resource IDs mentioned in conversations:
\`\`\`bash
grep -r "arn:aws\|i-[0-9a-f]\|sg-[0-9a-f]\|vpc-[0-9a-f]" $OUTPUT_DIR/conversations/
\`\`\`

To search for specific AWS services:
\`\`\`bash
grep -r "ECS\|Fargate\|RDS\|S3\|CloudFormation" $OUTPUT_DIR/conversations/
\`\`\`

EOF

echo ""
echo "🎉 Export completed successfully!"
echo "📁 Results saved to: $OUTPUT_DIR"
echo "📋 Summary: $OUTPUT_DIR/README.md"
echo ""
echo "💡 Next steps:"
echo "   1. Review conversations in: $OUTPUT_DIR/conversations/"
echo "   2. Check summary report: $OUTPUT_DIR/summary/export_summary.md"
echo "   3. Search for AWS resources: grep -r 'arn:aws' $OUTPUT_DIR/conversations/"
echo "   4. Search for deployment info: grep -r 'deploy\|stack\|CloudFormation' $OUTPUT_DIR/conversations/" 