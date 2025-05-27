#!/bin/bash

# Quick Cursor Database Explorer
# Helps understand the structure before full export

set -euo pipefail

CURSOR_DB="/Users/luismartins/Library/Application Support/Cursor/User/globalStorage/state.vscdb"

if [[ ! -f "$CURSOR_DB" ]]; then
    echo "❌ Cursor database not found at: $CURSOR_DB"
    exit 1
fi

echo "🔍 Exploring Cursor Database Structure"
echo "📁 Database: $CURSOR_DB"
echo "📊 Size: $(du -h "$CURSOR_DB" | cut -f1)"
echo ""

echo "📋 Available Tables:"
sqlite3 "$CURSOR_DB" ".tables" | tr ' ' '\n' | sort | nl
echo ""

echo "🔍 Looking for chat-related tables..."
CHAT_TABLES=$(sqlite3 "$CURSOR_DB" ".tables" | tr ' ' '\n' | grep -i -E "(chat|conversation|message|history)" || echo "No obvious chat tables found")
if [[ "$CHAT_TABLES" != "No obvious chat tables found" ]]; then
    echo "Found potential chat tables:"
    echo "$CHAT_TABLES" | nl
else
    echo "$CHAT_TABLES"
fi
echo ""

echo "🔍 Examining table schemas (first 10 tables)..."
TABLES=$(sqlite3 "$CURSOR_DB" ".tables" | tr ' ' '\n' | head -10)
for table in $TABLES; do
    echo "--- Table: $table ---"
    sqlite3 "$CURSOR_DB" ".schema $table" 2>/dev/null || echo "Could not get schema for $table"
    
    # Get row count
    ROW_COUNT=$(sqlite3 "$CURSOR_DB" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
    echo "Rows: $ROW_COUNT"
    
    # Show sample data (first row)
    if [[ "$ROW_COUNT" -gt 0 ]]; then
        echo "Sample data:"
        sqlite3 -header "$CURSOR_DB" "SELECT * FROM $table LIMIT 1;" 2>/dev/null || echo "Could not retrieve sample data"
    fi
    echo ""
done

echo "🔍 Searching for potential conversation data..."
# Look for tables with text content that might be conversations
for table in $(sqlite3 "$CURSOR_DB" ".tables" | tr ' ' '\n'); do
    # Check if table has text-like columns
    COLUMNS=$(sqlite3 "$CURSOR_DB" "PRAGMA table_info($table);" 2>/dev/null | grep -i -E "(text|varchar|char)" || true)
    if [[ -n "$COLUMNS" ]]; then
        ROW_COUNT=$(sqlite3 "$CURSOR_DB" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
        if [[ "$ROW_COUNT" -gt 0 ]]; then
            echo "Table '$table' has text columns and $ROW_COUNT rows"
            echo "Columns: $COLUMNS"
            
            # Try to find conversation-like content
            SAMPLE=$(sqlite3 "$CURSOR_DB" "SELECT * FROM $table LIMIT 1;" 2>/dev/null | head -c 200 || echo "")
            if [[ -n "$SAMPLE" ]]; then
                echo "Sample: ${SAMPLE}..."
            fi
            echo ""
        fi
    fi
done

echo "✅ Exploration complete!"
echo "💡 Run the full export with: bash scripts/export/cursor-chat-export.sh" 