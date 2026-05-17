#!/bin/bash

# --- 配置项 ---
SOURCE_URL="https://raw.githubusercontent.com/EhTagTranslation/Database/refs/heads/release/db.text.json"
JSON_FILE="db.text.json"
TEMP_TSV="tags_data.tsv"
DB_FILE="etag.db"

echo "🚀 开始构建 etag.db..."
# 1. 下载原始 JSON 数据
if [ ! -f "$JSON_FILE" ]; then
    echo "📥 正在下载原始 JSON 数据..."
    curl -L -o "$JSON_FILE" "$SOURCE_URL" || { echo "❌ 下载失败"; return 1; }
fi

# 2. 检查 JSON 文件是否有效
if ! jq '.' "$JSON_FILE" > /dev/null 2>&1; then
    echo "❌ 错误: $JSON_FILE 无效，尝试重新下载..."
    rm -f "$JSON_FILE"
    curl -L -o "$JSON_FILE" "$SOURCE_URL" || return 1
    if ! jq '.' "$JSON_FILE" > /dev/null 2>&1; then
        echo "❌ 错误: JSON 依然无效，请检查网络或源地址。"
        return 1
    fi
fi

echo "🛠️ 正在解析数据并写入 SQLite..."

# 3. 使用 jq 提取数据并生成临时 TSV
jq -r '
    .data[] | 
    .frontMatters.key as $ns | 
    .data | to_entries[] | 
    [
    $ns, 
    .key, 
    (if (.value.name and .value.name != "") then .value.name else .key end)
    ] | @tsv
' "$JSON_FILE" > "$TEMP_TSV"

# 4. 写入 SQLite
[ -f "$DB_FILE" ] && rm "$DB_FILE"
sqlite3 "$DB_FILE" <<EOF
CREATE TABLE tags (
    namespace TEXT,
    en TEXT,
    zh TEXT
);
.separator "\t"
.import "$TEMP_TSV" tags
CREATE INDEX idx_en ON tags(en);
CREATE INDEX idx_ns_en ON tags(namespace, en);
SELECT '📊 数据库条数: ' || count(*) FROM tags;
EOF

# 5. 清理
rm -f "$TEMP_TSV"
echo "✅ 数据库构建完成: $DB_FILE"
# 测试查询示例
# sqlite3 etag.db "SELECT * FROM tags WHERE namespace = 'character' LIMIT 5;"