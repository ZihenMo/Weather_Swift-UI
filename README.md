# 天气

面向 iOS 15 及以上 iPhone 的天气应用，提供当前位置与常用地点的天气查询。

## 主要能力

- 查看当前天气、未来七天预报及逐小时气温和降水概率。
- 搜索、预览和收藏地点，恢复上次选择。
- 使用缓存查看离线天气，并明确显示数据时间与来源。
- 支持简体中文、繁体中文、英语及辅助功能字号。

## 项目组织

```text
WeatherJournal/
├── App/          应用入口与导航
├── Modules/
│   ├── Weather/  天气查询与展示
│   └── Places/   定位、搜索与收藏
├── Shared/       共用能力与样式
└── Resources/    图片与多语言资源
```

`Configuration/` 管理环境配置，`scripts/` 和 `fastlane/` 提供开发与交付入口。详细目录、模块边界和代码规则见 [[AGENTS|项目规范]]。

## 环境与依赖

- Xcode 版本：`.xcode-version`
- Ruby 版本：`.ruby-version`，由 rbenv 等版本管理器提供。
- Bundler 版本：`.bundler-version`
- 打包工具版本：`Gemfile.lock`，包含 Fastlane 和蒲公英插件。
- 应用依赖：Apple SDK。

准备项目依赖：

```sh
./scripts/bootstrap.sh
```

## 打开与配置

使用 Xcode 打开 `WeatherJournal.xcodeproj`，选择 `WeatherJournal` scheme 和 iPhone 运行目标。模拟器位置可在 Features → Location 中设置。

服务地址采用 `Configuration/Base.xcconfig` 默认值。本地调整使用 `Configuration/Local.xcconfig.example` 的副本 `Local.xcconfig`，该文件不入库。

## 开发与交付入口

| 用途 | 命令 |
|---|---|
| 静态检查 | `./scripts/check.sh` |
| Ad Hoc 本地打包 | `./scripts/bundle.sh exec fastlane ios package` |
| 上传已有 IPA | `./scripts/bundle.sh exec fastlane ios distribute` |

打包使用本机已安装的证书和描述文件，产物位于 `artifacts/`。签名、IPA 路径和发布说明的环境变量见 `fastlane/.env.example`；蒲公英密钥使用 `PGYER_API_KEY`。

## 数据来源

天气与地点搜索由 Open-Meteo 提供，设备定位与地名解析使用 Core Location。

- [天气接口](https://open-meteo.com/en/docs)
- [地点搜索接口](https://open-meteo.com/en/docs/geocoding-api)
- [服务使用条款](https://open-meteo.com/en/terms)
