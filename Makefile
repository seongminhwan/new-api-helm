# New-API Helm Chart Makefile
# This Makefile provides convenient commands for managing the New-API Helm chart

# Default values
NAMESPACE ?= new-api
RELEASE_NAME ?= new-api
VALUES_FILE ?= values.yaml
CHART_PATH ?= .

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help install uninstall upgrade status lint test package clean dev prod external-db

# Default target
help: ## 显示帮助信息
	@echo "$(BLUE)New-API Helm Chart 管理命令$(NC)"
	@echo ""
	@echo "$(YELLOW)基本命令:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)环境变量:$(NC)"
	@echo "  NAMESPACE     Kubernetes 命名空间 (默认: new-api)"
	@echo "  RELEASE_NAME  Helm release 名称 (默认: new-api)"
	@echo "  VALUES_FILE   Values 文件路径 (默认: values.yaml)"
	@echo ""
	@echo "$(YELLOW)示例:$(NC)"
	@echo "  make install                    # 使用默认配置安装"
	@echo "  make install VALUES_FILE=examples/values-production.yaml"
	@echo "  make status NAMESPACE=production"
	@echo "  make upgrade VALUES_FILE=examples/values-development.yaml"

install: ## 安装 New-API
	@echo "$(BLUE)安装 New-API...$(NC)"
	./scripts/install.sh -n $(NAMESPACE) -r $(RELEASE_NAME) -f $(VALUES_FILE)

install-dry-run: ## 执行安装 dry run
	@echo "$(BLUE)执行安装 dry run...$(NC)"
	./scripts/install.sh -n $(NAMESPACE) -r $(RELEASE_NAME) -f $(VALUES_FILE) --dry-run

uninstall: ## 卸载 New-API
	@echo "$(YELLOW)卸载 New-API...$(NC)"
	./scripts/uninstall.sh -n $(NAMESPACE) -r $(RELEASE_NAME)

uninstall-all: ## 卸载 New-API 并删除所有数据
	@echo "$(YELLOW)卸载 New-API 并删除所有数据...$(NC)"
	./scripts/uninstall.sh -n $(NAMESPACE) -r $(RELEASE_NAME) --delete-pvc --delete-namespace

upgrade: ## 升级 New-API
	@echo "$(BLUE)升级 New-API...$(NC)"
	./scripts/upgrade.sh -n $(NAMESPACE) -r $(RELEASE_NAME) -f $(VALUES_FILE)

upgrade-dry-run: ## 执行升级 dry run
	@echo "$(BLUE)执行升级 dry run...$(NC)"
	./scripts/upgrade.sh -n $(NAMESPACE) -r $(RELEASE_NAME) -f $(VALUES_FILE) --dry-run

status: ## 检查部署状态
	@echo "$(BLUE)检查部署状态...$(NC)"
	./scripts/status.sh -n $(NAMESPACE) -r $(RELEASE_NAME)

status-all: ## 检查详细状态（包含日志、事件、指标）
	@echo "$(BLUE)检查详细状态...$(NC)"
	./scripts/status.sh -n $(NAMESPACE) -r $(RELEASE_NAME) --all

logs: ## 查看应用日志
	@echo "$(BLUE)查看应用日志...$(NC)"
	./scripts/status.sh -n $(NAMESPACE) -r $(RELEASE_NAME) --logs

logs-follow: ## 实时跟踪应用日志
	@echo "$(BLUE)实时跟踪应用日志...$(NC)"
	./scripts/status.sh -n $(NAMESPACE) -r $(RELEASE_NAME) --follow

lint: ## 检查 Helm chart 语法
	@echo "$(BLUE)检查 Helm chart 语法...$(NC)"
	helm lint $(CHART_PATH)

test: ## 运行 Helm chart 测试
	@echo "$(BLUE)运行 Helm chart 测试...$(NC)"
	helm test $(RELEASE_NAME) -n $(NAMESPACE)

template: ## 渲染模板（不安装）
	@echo "$(BLUE)渲染 Helm 模板...$(NC)"
	helm template $(RELEASE_NAME) $(CHART_PATH) -f $(VALUES_FILE)

package: ## 打包 Helm chart
	@echo "$(BLUE)打包 Helm chart...$(NC)"
	helm package $(CHART_PATH)

clean: ## 清理打包文件
	@echo "$(BLUE)清理打包文件...$(NC)"
	rm -f *.tgz

# 预定义配置安装
dev: ## 使用开发环境配置安装
	@echo "$(BLUE)使用开发环境配置安装...$(NC)"
	$(MAKE) install VALUES_FILE=examples/values-development.yaml NAMESPACE=new-api-dev

prod: ## 使用生产环境配置安装
	@echo "$(BLUE)使用生产环境配置安装...$(NC)"
	$(MAKE) install VALUES_FILE=examples/values-production.yaml

external-db: ## 使用外部数据库配置安装
	@echo "$(BLUE)使用外部数据库配置安装...$(NC)"
	$(MAKE) install VALUES_FILE=examples/values-external-db.yaml

# 开发相关命令
dev-install: dev ## 开发环境安装（别名）

dev-status: ## 检查开发环境状态
	@echo "$(BLUE)检查开发环境状态...$(NC)"
	$(MAKE) status NAMESPACE=new-api-dev

dev-logs: ## 查看开发环境日志
	@echo "$(BLUE)查看开发环境日志...$(NC)"
	$(MAKE) logs NAMESPACE=new-api-dev

dev-uninstall: ## 卸载开发环境
	@echo "$(YELLOW)卸载开发环境...$(NC)"
	$(MAKE) uninstall NAMESPACE=new-api-dev

# 生产相关命令
prod-status: ## 检查生产环境状态
	@echo "$(BLUE)检查生产环境状态...$(NC)"
	$(MAKE) status VALUES_FILE=examples/values-production.yaml

prod-upgrade: ## 升级生产环境
	@echo "$(BLUE)升级生产环境...$(NC)"
	$(MAKE) upgrade VALUES_FILE=examples/values-production.yaml

prod-logs: ## 查看生产环境日志
	@echo "$(BLUE)查看生产环境日志...$(NC)"
	$(MAKE) logs VALUES_FILE=examples/values-production.yaml

# 备份和恢复
backup: ## 创建数据备份
	@echo "$(BLUE)创建数据备份...$(NC)"
	kubectl create job --from=cronjob/$(RELEASE_NAME)-backup manual-backup-$(shell date +%Y%m%d-%H%M%S) -n $(NAMESPACE)

# 调试命令
debug: ## 调试模式（显示详细信息）
	@echo "$(BLUE)调试信息:$(NC)"
	@echo "NAMESPACE: $(NAMESPACE)"
	@echo "RELEASE_NAME: $(RELEASE_NAME)"
	@echo "VALUES_FILE: $(VALUES_FILE)"
	@echo "CHART_PATH: $(CHART_PATH)"
	@echo ""
	helm list -n $(NAMESPACE)
	@echo ""
	kubectl get all -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)

# 快速命令
quick-install: ## 快速安装（跳过确认）
	@echo "$(BLUE)快速安装...$(NC)"
	./scripts/install.sh -n $(NAMESPACE) -r $(RELEASE_NAME) --no-create-namespace

rollback: ## 回滚到上一个版本
	@echo "$(YELLOW)回滚到上一个版本...$(NC)"
	helm rollback $(RELEASE_NAME) -n $(NAMESPACE)

history: ## 查看发布历史
	@echo "$(BLUE)查看发布历史...$(NC)"
	helm history $(RELEASE_NAME) -n $(NAMESPACE)

# 验证命令
verify: ## 验证部署
	@echo "$(BLUE)验证部署...$(NC)"
	@echo "检查 Helm release..."
	helm status $(RELEASE_NAME) -n $(NAMESPACE)
	@echo ""
	@echo "检查 Pod 状态..."
	kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)
	@echo ""
	@echo "检查 Service..."
	kubectl get svc -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)

# 清理命令
clean-all: clean uninstall-all ## 完全清理（卸载并删除所有文件）

# 帮助命令的详细版本
help-detailed: ## 显示详细帮助
	@echo "$(BLUE)New-API Helm Chart 详细帮助$(NC)"
	@echo ""
	@echo "$(YELLOW)安装命令:$(NC)"
	@echo "  install          - 安装 New-API"
	@echo "  install-dry-run  - 执行安装 dry run"
	@echo "  dev              - 使用开发配置安装"
	@echo "  prod             - 使用生产配置安装"
	@echo "  external-db      - 使用外部数据库配置安装"
	@echo ""
	@echo "$(YELLOW)管理命令:$(NC)"
	@echo "  upgrade          - 升级部署"
	@echo "  upgrade-dry-run  - 执行升级 dry run"
	@echo "  uninstall        - 卸载部署"
	@echo "  uninstall-all    - 卸载并删除所有数据"
	@echo "  rollback         - 回滚到上一个版本"
	@echo ""
	@echo "$(YELLOW)监控命令:$(NC)"
	@echo "  status           - 检查基本状态"
	@echo "  status-all       - 检查详细状态"
	@echo "  logs             - 查看日志"
	@echo "  logs-follow      - 实时跟踪日志"
	@echo "  verify           - 验证部署"
	@echo ""
	@echo "$(YELLOW)开发命令:$(NC)"
	@echo "  lint             - 检查语法"
	@echo "  test             - 运行测试"
	@echo "  template         - 渲染模板"
	@echo "  package          - 打包 chart"
	@echo "  debug            - 显示调试信息"