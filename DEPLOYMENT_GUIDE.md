# New-API Helm Chart 部署指南

## 概述

这是一个完整的 Helm Chart，用于在 Kubernetes 集群中部署高可用的 New-API 服务。该 Chart 支持单节点和高可用部署模式，包含 MySQL 和 Redis 的可选高可用配置。

## 快速开始

### 1. 基本安装

```bash
# 使用默认配置安装
make install

# 或者使用脚本
./scripts/install.sh
```

### 2. 开发环境安装

```bash
# 使用开发环境配置
make dev

# 或者
./scripts/install.sh -f examples/values-development.yaml -n new-api-dev
```

### 3. 生产环境安装

```bash
# 使用生产环境配置
make prod

# 或者
./scripts/install.sh -f examples/values-production.yaml
```

### 4. 外部数据库安装

```bash
# 使用外部数据库配置
make external-db

# 或者
./scripts/install.sh -f examples/values-external-db.yaml
```

## 配置选项

### 主要配置文件

- **values.yaml**: 默认配置文件
- **examples/values-development.yaml**: 开发环境配置
- **examples/values-production.yaml**: 生产环境配置
- **examples/values-external-db.yaml**: 外部数据库配置

### 核心配置项

#### New-API 应用配置

```yaml
newapi:
  image:
    repository: calciumion/new-api
    tag: "v0.6.6"
  
  master:
    enabled: true
    replicaCount: 1
  
  slave:
    enabled: true
    replicaCount: 2
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
```

#### MySQL 配置

```yaml
mysql:
  enabled: true  # 启用内置 MySQL
  ha:
    enabled: false  # 高可用模式
    replicaCount: 3
  
  # 外部 MySQL
  external:
    host: "mysql.example.com"
    database: "new_api"
    username: "newapi_user"
    password: "secure_password"
```

#### Redis 配置

```yaml
redis:
  enabled: true  # 启用内置 Redis
  cluster:
    enabled: false  # 集群模式
    replicaCount: 6
  
  # 外部 Redis
  external:
    host: "redis.example.com"
    port: 6379
    password: "redis_password"
```

## 管理命令

### 使用 Makefile

```bash
# 查看所有可用命令
make help

# 安装相关
make install                    # 基本安装
make install-dry-run           # 安装预览
make dev                       # 开发环境安装
make prod                      # 生产环境安装

# 管理相关
make upgrade                   # 升级部署
make uninstall                 # 卸载部署
make status                    # 检查状态
make logs                      # 查看日志

# 开发相关
make lint                      # 语法检查
make template                  # 模板渲染
make package                   # 打包 Chart
```

### 使用脚本

```bash
# 安装脚本
./scripts/install.sh --help

# 升级脚本
./scripts/upgrade.sh --help

# 状态检查脚本
./scripts/status.sh --help

# 卸载脚本
./scripts/uninstall.sh --help
```

## 监控和维护

### 状态检查

```bash
# 基本状态检查
make status

# 详细状态检查（包含日志、事件、指标）
make status-all

# 实时日志跟踪
make logs-follow
```

### 备份

```bash
# 手动创建备份
make backup

# 查看备份任务状态
kubectl get cronjob -n new-api
```

### 升级

```bash
# 升级到新版本
make upgrade

# 升级预览
make upgrade-dry-run

# 回滚到上一个版本
make rollback
```

## 高可用部署

### MySQL 高可用

```yaml
mysql:
  enabled: true
  ha:
    enabled: true
    replicaCount: 3
    persistence:
      enabled: true
      size: 100Gi
```

### Redis 集群

```yaml
redis:
  enabled: true
  cluster:
    enabled: true
    replicaCount: 6  # 3 masters + 3 slaves
```

### New-API 高可用

```yaml
newapi:
  master:
    replicaCount: 2  # 多个 master 节点
  
  slave:
    replicaCount: 5
    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 20
```

## 安全配置

### RBAC

```yaml
rbac:
  create: true
```

### 网络策略

```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
```

### Pod 安全上下文

```yaml
security:
  podSecurityContext:
    fsGroup: 1000
    runAsNonRoot: true
    runAsUser: 1000
```

## 故障排除

### 常见问题

1. **Pod 无法启动**
   ```bash
   kubectl describe pod -n new-api -l app.kubernetes.io/instance=new-api
   ```

2. **数据库连接失败**
   ```bash
   kubectl logs -n new-api deployment/new-api-master
   ```

3. **存储问题**
   ```bash
   kubectl get pvc -n new-api
   kubectl describe pvc -n new-api
   ```

### 调试命令

```bash
# 查看所有资源
kubectl get all -n new-api

# 查看事件
kubectl get events -n new-api --sort-by='.lastTimestamp'

# 进入容器调试
kubectl exec -it -n new-api deployment/new-api-master -- /bin/sh
```

## 性能优化

### 资源配置

```yaml
newapi:
  master:
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
```

### 自动扩缩容

```yaml
newapi:
  slave:
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
      targetMemoryUtilizationPercentage: 80
```

## 监控集成

### Prometheus

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics
```

### Grafana 仪表板

Chart 包含预配置的 ServiceMonitor，可以与 Prometheus Operator 集成。

## 备份和恢复

### 自动备份

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  retention: 7  # 保留 7 天
```

### 手动备份

```bash
# 创建手动备份任务
kubectl create job --from=cronjob/new-api-backup manual-backup-$(date +%Y%m%d) -n new-api
```

## 版本升级

### 升级流程

1. 备份当前数据
2. 更新 Chart 版本
3. 执行升级
4. 验证功能
5. 如有问题，执行回滚

```bash
# 升级命令
helm upgrade new-api . -n new-api -f values.yaml

# 回滚命令
helm rollback new-api -n new-api
```

## 支持和贡献

如果您遇到问题或有改进建议，请：

1. 查看故障排除部分
2. 检查 GitHub Issues
3. 提交新的 Issue 或 Pull Request

## 许可证

本项目遵循 MIT 许可证。