# New API Helm Chart

[![Helm](https://img.shields.io/badge/Helm-v3-blue)](https://helm.sh/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.19+-blue)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

一个用于部署 [New-API](https://github.com/Calcium-Ion/new-api) 服务的 Helm Chart，支持高可用性部署。

## 📋 功能特性

- ✅ **高可用架构**: 支持 Master/Slave 模式部署
- ✅ **内置数据库**: 集成 MySQL StatefulSet
- ✅ **缓存支持**: 集成 Redis 缓存
- ✅ **自动扩缩容**: 支持 HPA (Horizontal Pod Autoscaler)
- ✅ **持久化存储**: 支持数据持久化
- ✅ **安全配置**: 自动生成密钥和安全配置
- ✅ **监控集成**: 支持 Prometheus 监控
- ✅ **网络策略**: 支持 Kubernetes NetworkPolicy
- ✅ **备份机制**: 支持定时备份

## 🚀 快速开始

### 前置要求

- Kubernetes 1.19+
- Helm 3.0+
- 至少 2GB 可用内存
- 至少 10GB 可用存储空间

### 添加 Helm 仓库

```bash
# 添加仓库 (请替换为实际的GitHub Pages地址)
helm repo add new-api https://seongminhwan.github.io/new-api-helm/

# 更新仓库索引
helm repo update
```

### 安装 New API

```bash
# 使用默认配置安装
helm install my-new-api new-api/new-api

# 或者使用自定义配置
helm install my-new-api new-api/new-api -f custom-values.yaml
```

### 访问服务

```bash
# 获取服务访问地址
kubectl get svc my-new-api

# 如果启用了 Ingress
kubectl get ingress my-new-api
```

## ⚙️ 配置说明

### 基本配置

```yaml
# values.yaml
newapi:
  master:
    enabled: true
    replicaCount: 1
  slave:
    enabled: false
    replicaCount: 2

mysql:
  enabled: true
  auth:
    database: "newapi"
    username: "newapi"

redis:
  enabled: true
  auth:
    enabled: true
```

### 高可用配置

```yaml
# 启用高可用模式
newapi:
  master:
    enabled: true
    replicaCount: 2
  slave:
    enabled: true
    replicaCount: 3

# 启用自动扩缩容
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### 外部数据库配置

```yaml
# 使用外部 MySQL
mysql:
  enabled: false
  external:
    host: "mysql.example.com"
    port: 3306
    username: "newapi"
    password: "your-password"
    database: "newapi"

# 使用外部 Redis
redis:
  enabled: false
  external:
    host: "redis.example.com"
    port: 6379
    password: "your-redis-password"
    database: 0
```

## 🔧 高级配置

### 持久化存储

```yaml
newapi:
  master:
    persistence:
      enabled: true
      size: 10Gi
      storageClass: "fast-ssd"
```

### Ingress 配置

```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: new-api-tls
      hosts:
        - api.example.com
```

### 监控配置

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    labels:
      release: prometheus
```

## 📊 监控和日志

### Prometheus 监控

Chart 支持 ServiceMonitor 资源，可以与 Prometheus Operator 集成：

```yaml
monitoring:
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics
```

### 日志收集

```yaml
logging:
  level: "info"
  format: "json"
  output: "stdout"
```

## 🔐 安全配置

### 密钥管理

Chart 会自动生成以下密钥：
- `SESSION_SECRET`: 32位随机字符串
- `CRYPTO_SECRET`: 32位随机字符串
- MySQL 密码: 16位随机字符串
- Redis 密码: 16位随机字符串

也可以手动指定：

```yaml
config:
  session:
    secret: "your-session-secret"
  crypto:
    secret: "your-crypto-secret"
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

## 🛠️ 运维操作

### 升级

```bash
# 升级到新版本
helm upgrade my-new-api new-api/new-api

# 查看升级历史
helm history my-new-api

# 回滚到上一个版本
helm rollback my-new-api
```

### 备份

Chart 支持定时备份功能：

```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # 每天凌晨2点
  retention: 7  # 保留7天
```

### 故障排除

```bash
# 查看 Pod 状态
kubectl get pods -l app.kubernetes.io/name=new-api

# 查看日志
kubectl logs -l app.kubernetes.io/name=new-api -f

# 查看配置
kubectl get configmap my-new-api-config -o yaml
kubectl get secret my-new-api-secrets -o yaml
```

## 📚 完整配置参考

查看 [values.yaml](values.yaml) 文件获取所有可配置参数的详细说明。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🔗 相关链接

- [New-API 项目](https://github.com/Calcium-Ion/new-api)
- [New-API 文档](https://docs.newapi.pro/)
- [Helm 官方文档](https://helm.sh/docs/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)

---

## 📞 支持

如果您在使用过程中遇到问题，请：

1. 查看 [故障排除](#故障排除) 部分
2. 搜索现有的 [Issues](https://github.com/seongminhwan/new-api-helm/issues)
3. 创建新的 Issue 描述您的问题

**⭐ 如果这个项目对您有帮助，请给我们一个 Star！**