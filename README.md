# XNode

中文增强版 **Xboard-Node** CLI 管理器。交互参考 [V2bX-script](https://github.com/wyx2685/V2bX-script)。

## 一行安装

```bash
wget -N "https://raw.githubusercontent.com/mbwso/xnode/main/install.sh" && bash install.sh
```

> 新手上传 GitHub 请看：[docs/上传到GitHub教程.md](docs/上传到GitHub教程.md)

安装完成后：

```bash
xnode              # 管理菜单
xnode generate     # 一键配置
xnode start        # 启动
xnode log          # 日志
```

## CLI 子命令

| 命令 | 说明 |
|------|------|
| `xnode` | 管理菜单 |
| `xnode install` | 安装/更新环境 |
| `xnode generate` | 一键生成配置 |
| `xnode start/stop/restart` | 服务控制 |
| `xnode status` | 状态 |
| `xnode log` | 日志 |
| `xnode update_shell` | 更新管理脚本 |
| `xnode version` | 版本 |

## 与 V2bX 对比

| V2bX | XNode |
|------|-------|
| `.../V2bX-script/master/install.sh` | `.../xnode/main/install.sh` |
| `/usr/bin/V2bX` + 别名 `v2bx` | `/usr/bin/xnode` |
| `/usr/local/V2bX/` | `/opt/xnode/` |

## 配置路径

| 文件 | 路径 |
|------|------|
| XNode 配置 | `/etc/xnode/config.json` |
| sing-box | `/etc/sing-box/config.json` |

## 发布

GitHub 仓库：**mbwso/xnode**

## License

MIT
