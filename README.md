# DeepSeek for BlackBerry 10

> 一个跑在 BlackBerry Q20 上的原生 DeepSeek 聊天客户端。
> 2026 年的机器，2012 年的框架，2026 年的模型。

![platform](https://img.shields.io/badge/platform-BlackBerry%2010%20(10.3.3)-000000)
![language](https://img.shields.io/badge/C%2B%2B%20%2B%20QML-Cascades-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## 这是什么

黑莓 10 是 2013 年的系统，官方商店早已关闭。但设备本身还能用——尤其 Q20 那块屏幕和键盘，打字体验放到今天依然很好。

这个项目把 DeepSeek 的 API 接进了一个**原生的 Cascades 应用**：

- 不是安卓套壳，不是网页封装，是真正的 BB10 原生程序（C++ + QML）
- 手机直连 `api.deepseek.com`，**没有中间服务器**
- 单页聊天界面，键盘输入、气泡消息、上下文保持

## 功能

| 功能 | 状态 |
|---|---|
| 文字对话（deepseek-chat） | ✅ |
| 多轮上下文 | ✅ |
| API Key 本地保存 | ✅ |
| 深色聊天界面 | ✅ |
| 流式输出（逐字） | ❌ 未实现 |
| 历史记录持久化 | ❌ 未实现 |
| 图片/文件 | ❌ 不支持 |

## 界面

```
┌──────────────────────────┐
│        DeepSeek    设置  │
├──────────────────────────┤
│  ┌────────────────────┐  │
│  │ 你好，有什么可以…  │  │  ← 助手（深灰）
│  └────────────────────┘  │
│           ┌───────────┐  │
│           │ 你好      │  │  ← 你（蓝色，右对齐）
│           └───────────┘  │
├──────────────────────────┤
│ 输入消息…          [发送] │
└──────────────────────────┘
```

## 构建

### 需要的环境

- Linux（本项目在 Ubuntu 26.04 上验证）
- [Podman](https://podman.io/)（或 Docker）
- BB10 NDK **10.3.1**（用现成镜像，不需要自己装）

### 一键构建

```bash
./scripts/build.sh
```

它会：

1. 拉取 `accupara/bbndk` 镜像（约 2.9 GB，只需一次）
2. 在容器里用 qmake + qcc 交叉编译出 ARM 二进制
3. 用 `blackberry-nativepackager -devMode` 打包成 `dist/deepseek.bar`

### 手动构建

```bash
podman run --rm --user 0 -v "$PWD:/work:Z" -w /work docker.io/accupara/bbndk bash -lc '
  source /home/admin/bin/bbndk/bbndk-env_10_3_1_995.sh
  qmake deepseek.pro && make
  blackberry-nativepackager -package dist/deepseek.bar -devMode \
    bar-descriptor.xml -C . deepseek icon.png -e icon.png icon.png
'
```

## 安装

> 不想自己编译？直接下载 [`dist/deepseek.bar`](dist/deepseek.bar)（141 KB，已构建好）。

### 前提

- 手机已 **root**（AutoRoot v4，能 SSH 进 `root@169.254.0.1`）
- 已安装 `/var/rootdata/installer`（AutoRoot 自带）

### 方法一：用脚本

```bash
./scripts/install.sh
```

### 方法二：手动

设备上的安装器要求一个特殊格式的 ZIP（`MANIFEST` + `pkg.bar`）：

```bash
# 1. 取出包的元信息
ID=$(unzip -p dist/deepseek.bar META-INF/MANIFEST.MF | grep '^Package-Id:' | cut -d' ' -f2)
VER=$(unzip -p dist/deepseek.bar META-INF/MANIFEST.MF | grep '^Package-Version:' | cut -d' ' -f2)
NAME=$(unzip -p dist/deepseek.bar META-INF/MANIFEST.MF | grep '^Package-Name:' | cut -d' ' -f2)

# 2. 组装
mkdir -p /tmp/pkg && cd /tmp/pkg
printf 'Package-Id: %s\nPackage-Name: %s\nPackage-Version: %s\n' "$ID" "$NAME" "$VER" > MANIFEST
cp /path/to/deepseek.bar pkg.bar
zip -q install.zip MANIFEST pkg.bar

# 3. 推送到手机并安装
cat install.zip | ssh root@169.254.0.1 "cat > /accounts/1000/shared/downloads/install.zip"
ssh root@169.254.0.1 "/var/rootdata/installer /accounts/1000/shared/downloads/install.zip"
```

### 手机端配置

1. 打开桌面上的 **DeepSeek**
2. 右上角 **设置** → 填入 [platform.deepseek.com](https://platform.deepseek.com) 的 API Key
3. 返回，开始聊天

## 构建时踩过的坑

这部分对手写 BB10 应用的人应该有用。

| 现象 | 原因 | 解决 |
|---|---|---|
| 启动 40ms 就退出，无日志 | `LD_LIBRARY_PATH` 缺 Qt 路径 | 描述文件加 `app/native/lib:/usr/lib:/usr/lib/qt4/lib` |
| 黑屏，`File not found: asset:///main.qml` | 描述文件没声明资源 | 改用 **qrc 编译进二进制**（最稳） |
| `ListModel is not a type` | 那是 QtQuick 的类型 | 用 Cascades 的 `ArrayDataModel` |
| `Connections is not a type` | Cascades 不内置 | 用 C++ 信号直连 QML 函数（`QVariant` 参数） |
| `ImagePaint is not a type` | Cascades 1.2/1.3 都没暴露 | 圆角做不了，只能纯色 |
| 请求 `status=0` | 系统证书库不是 PEM，Qt 读不到 | 把 CA 证书打进 App（`qrc:/ca.pem`） |
| HTTP 400 | `JSON.stringify` 对 QVariant 数组失效 | 手写 JSON 序列化 |
| 应用装不上（未签名） | — | **root 设备不校验签名**，`-devMode` 打包即可 |

## 项目结构

```
.
├── src/main.cpp          # C++：应用入口、QSettings、网络层
├── main.qml              # QML：聊天界面
├── resources.qrc         # 把 QML 和 CA 证书编译进二进制
├── ca.pem                # Mozilla 根证书集合（见下方许可）
├── deepseek.pro          # qmake 工程
├── bar-descriptor.xml    # BB10 应用描述
├── icon.png
├── scripts/
│   ├── build.sh
│   └── install.sh
└── dist/deepseek.bar     # 构建产物
```

## 已知限制

- **只支持 BB10 10.3.3**（descriptor 最低版本，其他版本未测试）
- **无圆角气泡**：Cascades 没有可用的圆角绘制能力
- **不支持流式输出**：一次性返回，长回答等待感明显
- **上下文只在内存**：关掉 App 就丢
- **仅 Q20 实测**

## 许可

- 本项目代码：MIT
- `ca.pem`：来自 [curl.se/ca](https://curl.se/ca/)，Mozilla 根证书集合，[MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/)
- DeepSeek 是深度求索公司的商标，本项目与其无关联

## 致谢

- [Cascades](https://developer.blackberry.com/) —— 黑莓的 UI 框架，比它该有的寿命长很多
- [accupara/bbndk](https://hub.docker.com/r/accupara/bbndk) —— 让 2017 年的 NDK 还能在 2026 年的系统上跑
- [imqinyu/NeteaseMusicBB10](https://github.com/imqinyu/NeteaseMusicBB10) —— 证明了 BB10 原生应用在今天仍然可写
- [Octo-o-o-o/bb10-volte](https://github.com/Octo-o-o-o/bb10-volte) —— 同一台机器上让 VoLTE 复活的项目
