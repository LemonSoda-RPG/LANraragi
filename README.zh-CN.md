**[English](README.md) | 简体中文**

<img src="public/favicon.ico" width="128">

LANraragi 中文说明
==================

> 本文档针对本仓库（`LemonSoda-RPG/LANraragi` fork），**不是上游英文 README 的逐句翻译**，
> 重点写"这个 fork 与上游的差异"和实际操作。上游功能说明请看
> [English README](README.md) 或 [官方文档](https://sugoi.gitbook.io/lanraragi/v/dev)。

漫画 / 本子归档与在线阅读服务器，基于 Mojolicious + Redis。

## 目录

- [这个 fork 与上游的差异](#这个-fork-与上游的差异)
- [快速开始（Docker）](#快速开始docker)
- [插件（registry）](#插件registry)
- [从源码构建](#从源码构建)
- [测试](#测试)
- [CI 说明](#ci-说明)
- [与上游同步](#与上游同步)
- [常见问题](#常见问题)

## 这个 fork 与上游的差异

| 方面 | 说明 |
|---|---|
| **插件分发** | 3 个自有插件不再直接内置在 `lib/LANraragi/Plugin/` 下，改由 [LemonSoda-RPG/Ougi](https://github.com/LemonSoda-RPG/Ougi) 这个插件仓库分发。镜像构建时会从仓库取回它们作为 managed 插件内置，所以**开箱可用、离线也可用**，同时又能从仓库升级 |
| **启动自动升级** | 容器**重启时**会自动刷新插件索引，并把通过仓库安装的插件升到最新版（可用 `LRR_AUTO_UPDATE_PLUGINS=0` 关闭） |
| **默认插件仓库** | 首次安装会自动配置 `LemonSoda-RPG/Ougi`（上游的 `Difegue/Ougi` 目前无法通过 LANraragi 的校验） |
| **中文元数据** | 自带 `ETagCN` 插件：从 E-Hentai 抓取元数据并把标签翻译成中文；另有 `AddEhentaiMetadata`（给没有 source 标签的档案补元数据）与 `DuplicateArchives`（查找重复档案） |
| **CI** | Linux 上跑完整测试套件；构建 Docker 镜像并推送到 GHCR（可选同时推 Docker Hub）；macOS 上验证 Homebrew 公式。Homebrew/Windows **不再自动跑**（保留手动触发） |
| **上游同步** | 已合并上游 `dev`（含密码哈希迁移 `Crypt::Passphrase`、nHentai 单引号搜索修复等 19 个提交） |

## 快速开始（Docker）

```yaml
services:
  lanraragi:
    image: ghcr.io/lemonsoda-rpg/lanraragi:dev   # 或本地构建的 lanraragi:local
    container_name: lanraragi
    ports:
      - "3000:3000"
    environment:
      - LRR_UID=1000        # 建议改成 id -u
      - LRR_GID=1000        # 建议改成 id -g
      # - LRR_AUTO_UPDATE_PLUGINS=0   # 关闭"重启自动升级插件"
    volumes:
      - ./content:/home/koyomi/lanraragi/content
      - ./thumb:/home/koyomi/lanraragi/thumb
      - ./database:/home/koyomi/lanraragi/database
      - ./sideloaded:/home/koyomi/lanraragi/lib/LANraragi/Plugin/Sideloaded
      - ./managed:/home/koyomi/lanraragi/lib/LANraragi/Plugin/Managed
    restart: unless-stopped
```

然后访问 <http://localhost:3000>。

### 各挂载点的作用

| 挂载点 | 作用 | 能不能删 |
|---|---|---|
| `content` | 漫画库，压缩包直接丢进去就会被扫描 | ❌ 你的数据 |
| `database` | 数据库 `database.rdb` | ❌ **删了要重新扫描全库** |
| `thumb` | 缩略图缓存 | ✅ 可删，会重建 |
| `sideloaded` | 手动放进去的插件 | — |
| `managed` | 从插件仓库安装的插件 | ✅ 可删（会回到镜像内置的版本） |

### ⚠️ 首次部署必须处理 `content` 权限

容器的启动脚本会自动修正 `database`、`thumb`、`managed` 的属主，**唯独不管 `content`**
（上游行为：只给 content 里的文件加只读权限）。而 bind mount 目录是 Docker 以 root 创建的，
结果是**宿主和容器都写不进去**。所以第一次部署要先：

```bash
sudo chown -R $(id -u):$(id -g) ./content
```

## 插件（registry）

本 fork 的插件走"仓库"机制：一个仓库就是一份 `registry.json` 加一堆制品文件。

### 安装 / 升级

镜像重启时会自动升级；想不重启立刻升，在容器内执行：

```bash
docker exec -u 1000:1000 -e HOME=/home/koyomi \
  -e PERL5LIB=/home/koyomi/perl5/lib/perl5 -w /home/koyomi/lanraragi \
  lanraragi perl /path/to/upgrade-plugins.pl
```

也可以走 API（前端没有插件管理界面，只能 API）：先在「设置 → 安全」里设一个 API Key，
再 `POST /api/plugins/install {"namespace":"...","registry":"REG_..."}`。

### 发布 / 更新插件

插件的源码在 **[LemonSoda-RPG/Ougi](https://github.com/LemonSoda-RPG/Ougi)** 仓库里，
流程和注意事项见那边的 README。要点：

- **已发布的版本不可变**：改动要开新版本目录（用 `tools/new-version.sh`）
- 索引 `registry.json` 由那边的 CI 自动生成并提交，不用手写
- 推送后 raw.githubusercontent.com 有约 5 分钟 CDN 缓存，刚推完可能还刷不到新版本

## 从源码构建

```bash
npm ci
npm run docker-build                       # 产出 lanraragi:latest
LRR_IMAGE=你的用户名/lanraragi npm run docker-build   # 自定义 tag
```

等价的手工命令：

```bash
docker build -t lanraragi:local -f tools/build/docker/Dockerfile .
# 想固定镜像内置插件的来源版本：
# docker build --build-arg OUGI_REF=<commit> -t lanraragi:local -f tools/build/docker/Dockerfile .
```

## 测试

```bash
npm test          # 等价于 prove -r -l -v tests/
```

`ImageMagickResizer.t` 和 `VipsResizer.t` 需要 Perl 的 `Image::Magick`：
**Docker 生产镜像里它们必然失败**（镜像用 vips，不含 ImageMagick），
在 macOS/Homebrew 环境下会正常执行。其余测试都应通过。

## CI 说明

| workflow | 触发 | 做什么 |
|---|---|---|
| `docker-publish.yml` | push / PR / 手动 | 构建 `linux/amd64` 镜像并推送到 GHCR；若配置了 Docker Hub 密钥则同时推送。PR 只构建不推送 |
| `push-brewtest.yml` | push 到 `dev` / 手动 | macOS 上从源码构建 Homebrew 公式并跑 `brew test`（内含完整测试套件），20–40 分钟 |
| `push-continuous-integration.yml` | push / PR / 手动 | Linux 上 ESLint + 完整测试套件 + Docker 集成测试 |
| `push-continous-delivery.yml` | **仅手动** | 上游的多架构（5 平台）镜像发布流程 |
| `release-delivery.yml` | **仅手动** | 上游的发布流程（Windows MSI + Discord 通知） |

**可选密钥**（`Settings → Secrets and variables → Actions`）：

| 名称 | 用途 |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名（不配则只推 GHCR） |
| `DOCKERHUB_TOKEN` | Docker Hub 访问令牌（**不是登录密码**） |

镜像名由 `docker-publish.yml` 顶部的 `IMAGE_NAME` 控制；GHCR 用内置 `GITHUB_TOKEN`，
所以**不配置任何密钥也能发布镜像**。

## 与上游同步

```bash
git remote add upstream https://github.com/Difegue/LANraragi.git   # 只需一次
git fetch upstream
git merge upstream/dev
# 解决冲突后推送
git push origin dev
```

⚠️ 注意：上游的内置插件更新**不会**自动同步到插件仓库（Ougi）。两者是独立的来源——
`lib/LANraragi/Plugin/` 下的是随镜像内置的副本，Ougi 里的是可安装/可升级的分发副本。
本 fork 里只有 3 个自有插件走 Ougi 分发，其余上游插件仍以内置形式提供。

## 常见问题

**Q：为什么我的插件装了却"卸不掉"？**
A：namespace 与镜像内置插件重名时会装不上（安装前会扫描整个 `Plugin/` 目录，大小写不敏感）。
本 fork 已把那 3 个自带插件从内置改为仓库分发，所以它们不存在这个问题。

**Q：升级插件后重启，会不会被镜像里的旧版本盖回去？**
A：不会。启动时的"播种"只在文件**不存在**时才复制，已有文件一律不动。

**Q：忘了 LANraragi 的登录密码怎么办？**
A：默认密码是 `kamimamita`（代码里的内置默认值）。若已改过又忘了，可以改 redis 里的
`LRR_CONFIG` 的 `password` 字段，或把 `enablepass` 设为 0 暂时关闭密码。

**Q：镜像里为什么没有 ImageMagick？**
A：生产镜像用 vips 做图像处理，ImageMagick 只在测试镜像/Homebrew 环境里存在。

## 致谢

上游项目：[Difegue/LANraragi](https://github.com/Difegue/LANraragi)（MIT License）。
打赏请支持[原作者](https://ko-fi.com/T6T2UP5N)。
