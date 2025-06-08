# New API Helm Chart 部署指南

## 版本信息
- **当前版本**: v0.1.1
- **MySQL配置**: 已修复为Bitnami MySQL
- **状态**: 生产就绪

## 快速部署

### 1. 添加Helm仓库
```bash
helm repo add new-api https://seongminhwan.github.io/new-api-helm/
helm repo update
```

### 2. 验证仓库
```bash
helm search repo new-api
```

### 3. 查看配置选项
```bash
helm show values new-api/new-api
```

### 4. 部署到Kubernetes
```bash
# 基础部署
helm install my-new-api new-api/new-api

# 自定义配置部署
helm install my-new-api new-api/new-api \
  --set mysql.auth.rootPassword=your-root-password \
  --set mysql.auth.password=your-user-password \
  --set redis.auth.password=your-redis-password
```

## 重要修复说明

### MySQL配置修复 (v0.1.1)
- ✅ **镜像**: 使用`bitnami/mysql:8.0`替代官方MySQL镜像
- ✅ **初始化**: 使用`initdbScripts`配置替代ConfigMap挂载
- ✅ **权限**: 解决"ERROR 1410 (42000): You are not allowed to create a user with GRANT"错误
- ✅ **远程访问**: 自动配置用户远程访问权限
- ✅ **字符集**: 配置UTF8MB4字符集支持

### 配置特性
```yaml
mysql:
  image:
    registry: docker.io
    repository: bitnami/mysql
    tag: "8.0"
  
  # 自动初始化脚本
  initdbScripts:
    01-init-database.sql: |
      CREATE DATABASE IF NOT EXISTS `new-api`;
      GRANT ALL PRIVILEGES ON `new-api`.* TO 'newapi'@'%';
      FLUSH PRIVILEGES;
```

## 验证部署

### 检查Pod状态
```bash
kubectl get pods -l app.kubernetes.io/name=new-api
```

### 检查服务状态
```bash
kubectl get svc -l app.kubernetes.io/name=new-api
```

### 查看日志
```bash
# 查看master节点日志
kubectl logs -l app.kubernetes.io/component=master

# 查看MySQL日志
kubectl logs -l app.kubernetes.io/component=mysql
```

## 故障排除

### MySQL连接问题
如果遇到MySQL连接错误，检查：
1. MySQL Pod是否正常运行
2. 密钥是否正确生成
3. 网络策略是否允许连接

```bash
# 检查MySQL连接
kubectl exec -it <mysql-pod> -- mysql -u newapi -p -h localhost new-api
```

### 常见错误解决
- **权限错误**: 确保使用Bitnami MySQL镜像和initdbScripts配置
- **连接超时**: 检查initContainer是否等待MySQL启动完成
- **字符集问题**: Bitnami MySQL已自动配置UTF8MB4

## 高可用配置

### 启用MySQL主从复制
```yaml
mysql:
  ha:
    enabled: true
    replicaCount: 3
```

### 启用自动扩缩容
```yaml
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

## 监控和备份

### 启用ServiceMonitor (Prometheus)
```yaml
monitoring:
  serviceMonitor:
    enabled: true
```

### 启用定时备份
```yaml
backup:
  enabled: true
  schedule: "0 2 * * *"  # 每天凌晨2点
```

## 安全配置

### 网络策略
```yaml
networkPolicy:
  enabled: true
  ingress:
    enabled: true
  egress:
    enabled: true
```

### Pod安全上下文
- 非root用户运行 (UID: 1000)
- 只读根文件系统
- 禁用特权提升

## 支持

如有问题，请查看：
- [GitHub Issues](https://github.com/seongminhwan/new-api-helm/issues)
- [New API官方文档](https://github.com/Calcium-Ion/new-api)

---

**注意**: 此版本已完全解决MySQL权限和连接问题，可安全用于生产环境。