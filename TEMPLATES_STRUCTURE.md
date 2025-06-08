# Templates 目录结构

本目录按照 Helm 官方最佳实践重新组织，将相关的 Kubernetes 资源按功能模块分组。

## 目录结构说明

```
templates/
├── _helpers.tpl              # Helm 模板助手函数
├── app/                      # 应用相关资源
│   ├── backup-cronjob.yaml   # 备份定时任务
│   ├── configmap.yaml        # 应用配置
│   ├── hpa.yaml              # 水平自动扩缩容
│   ├── master-deployment.yaml # 主节点部署
│   ├── master-pvc.yaml       # 主节点持久卷声明
│   ├── pdb.yaml              # Pod 中断预算
│   ├── service.yaml          # 应用服务
│   └── slave-deployment.yaml # 从节点部署
├── cache/                    # 缓存相关资源
│   ├── redis-service.yaml    # Redis 服务
│   └── redis-statefulset.yaml # Redis 有状态集
├── database/                 # 数据库相关资源
│   ├── mysql-init-configmap.yaml # MySQL 初始化配置
│   ├── mysql-service.yaml    # MySQL 服务
│   └── mysql-statefulset.yaml # MySQL 有状态集
├── monitoring/               # 监控相关资源
│   └── servicemonitor.yaml   # 服务监控
├── network/                  # 网络相关资源
│   ├── ingress.yaml          # 入口控制器
│   └── networkpolicy.yaml    # 网络策略
└── rbac/                     # 权限控制相关资源
    ├── rbac.yaml             # 角色和角色绑定
    ├── secret.yaml           # 密钥
    └── serviceaccount.yaml   # 服务账户
```

## 组织原则

1. **功能分组**: 按照应用的不同功能模块进行分组
2. **资源类型**: 相同类型的资源放在同一目录下
3. **依赖关系**: 考虑资源之间的依赖关系进行组织
4. **可维护性**: 便于查找、修改和维护

## 优势

- **清晰的结构**: 开发者可以快速找到相关的资源文件
- **模块化管理**: 每个功能模块独立管理，便于维护
- **团队协作**: 不同团队成员可以专注于特定的功能模块
- **版本控制**: 更好的版本控制和代码审查体验