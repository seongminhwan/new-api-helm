#!/bin/bash

# New API Helm Repository Update Script
# 用于更新GitHub Pages Helm仓库的脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印彩色消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 检查是否安装了helm
if ! command -v helm &> /dev/null; then
    print_message "❌ Helm未安装，请先安装Helm" $RED
    exit 1
fi

# 获取GitHub仓库信息
REPO_URL=""
if git remote get-url origin &> /dev/null; then
    ORIGIN_URL=$(git remote get-url origin)
    if [[ $ORIGIN_URL == *"github.com"* ]]; then
        # 提取用户名和仓库名
        if [[ $ORIGIN_URL == *".git" ]]; then
            REPO_PATH=${ORIGIN_URL%.git}
        else
            REPO_PATH=$ORIGIN_URL
        fi
        
        if [[ $REPO_PATH == *"github.com/"* ]]; then
            REPO_INFO=${REPO_PATH##*github.com/}
            REPO_INFO=${REPO_INFO##*:}  # 处理SSH格式
            USERNAME=${REPO_INFO%/*}
            REPO_NAME=${REPO_INFO#*/}
            REPO_URL="https://${USERNAME}.github.io/${REPO_NAME}/"
        fi
    fi
fi

# 如果无法自动获取，提示用户输入
if [[ -z "$REPO_URL" ]]; then
    print_message "⚠️  无法自动检测GitHub仓库信息" $YELLOW
    echo -n "请输入您的GitHub用户名: "
    read USERNAME
    echo -n "请输入仓库名称: "
    read REPO_NAME
    REPO_URL="https://${USERNAME}.github.io/${REPO_NAME}/"
fi

print_message "🔍 检测到的仓库URL: $REPO_URL" $BLUE

# 创建docs目录
print_message "📁 创建docs目录..." $BLUE
mkdir -p docs

# 打包Helm chart
print_message "📦 打包Helm chart..." $BLUE
helm package . -d docs/

# 生成仓库索引
print_message "📋 生成Helm仓库索引..." $BLUE
helm repo index docs/ --url "$REPO_URL"

# 显示生成的文件
print_message "✅ 生成完成！文件列表:" $GREEN
ls -la docs/

print_message "\n🚀 下一步操作:" $YELLOW
echo "1. 提交文件到GitHub:"
echo "   git add docs/"
echo "   git commit -m \"Update Helm repository\""
echo "   git push"
echo ""
echo "2. 在GitHub仓库设置中启用GitHub Pages:"
echo "   - 进入仓库设置 (Settings)"
echo "   - 找到 Pages 选项"
echo "   - 选择 \"Deploy from a branch\""
echo "   - 选择 \"main\" 分支的 \"/docs\" 文件夹"
echo "   - 保存设置"
echo ""
echo "3. 使用Helm仓库:"
echo "   helm repo add ${REPO_NAME} ${REPO_URL}"
echo "   helm repo update"
echo "   helm install my-new-api ${REPO_NAME}/new-api"

print_message "\n🎉 Helm仓库配置完成！" $GREEN