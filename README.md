# SalaryTrain

一场终端演出：sl (Steam Locomotive) 蒸汽火车从右向左驶过后，月薪喵 GIF 居中循环播放。

## 版本

当前 **v1.1.0** — 迁移至 Xcode 双 Target 工程，新增 Cocoa Launcher，兼容 macOS 10.15+。

## 构建（开发）

在 Xcode 中打开 `SalaryTrain.xcodeproj`，选择 **SalaryTrainApp** scheme → Product → Build (⌘B)。

输出路径：
```
~/Library/Developer/Xcode/DerivedData/SalaryTrain-*/Build/Products/Release/SalaryTrainApp.app
```

终端调试运行：
```sh
open Release/SalaryTrainApp.app --args --filled
```

## 渲染模式

| 模式 | 旗标 | 效果 | 默认阈值 |
|------|------|------|---------|
| bw-edge | `--bw-edge` （默认） | 斜线勾边猫（`/\|-` 画轮廓，眼睛实心，去花纹） | edgeThreshold=200, stripeThreshold=120 |
| outline | `--outline` | Sobel+NMS 边缘线稿，原色 | edgeThreshold=60 |
| filled | `--filled` | 全彩填充 | — |
| bw | `--bw` | 取模黑白白色剪影 | bwThreshold=128 |
| bw-dither | `--bw --dither` | Floyd-Steinberg 抖动黑白 | bwThreshold=128 |

### 阈值调整

```sh
--edge-threshold N    # Sobel 边缘阈值（越小边缘越多）
--bw-threshold N      # 黑白亮度阈值（越小白色越多）
--stripe-threshold N  # 花纹抑制阈值（bw-edge，越小去花纹越多）
```

### 调试/预览

```sh
--preview-train       # 打印 sl D51 火车 ASCII art
--dump-frame          # 静态渲染一帧猫（所有模式都可用）
--cat-only            # 只播放猫动画（跳过火车）
```

## 分发

`.app` 用 ad-hoc 签名，首次运行需右键 → 打开（绕过 Gatekeeper）。若 Desktop 副本被隔离，去隔离：

```sh
xattr -cr SalaryTrainApp.app
```

参数传递：
```sh
open SalaryTrainApp.app                       # 默认 bw-edge 模式
open SalaryTrainApp.app --args --filled       # 全彩填充
open SalaryTrainApp.app --args --cat-only     # 只播猫
```

按 `Ctrl+C` 退出。

## 项目结构

```
Terminal-Animate-App/
├── SalaryTrain.xcodeproj/         # Xcode 双 Target 工程
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/
│       ├── SalaryTrain.xcscheme       # CLI Tool target
│       └── SalaryTrainApp.xcscheme    # .app bundle target
├── Info.plist
├── Launcher/
│   └── main.swift                 # Cocoa 原生启动器（NSApplication + Process/applescript）
├── Sources/
│   ├── SalaryTrain/               # 全部 Swift 源码（单模块编译）
│   │   ├── main.swift             # CLI 解析 + 编排入口
│   │   ├── Stage.swift            # 终端控制（alt screen, 240×40, diff draw, 窗口居中）
│   │   ├── Show.swift             # 演出主循环（火车→猫，猫预渲染）
│   │   ├── Act.swift              # Act 协议
│   │   ├── TrainAct.swift         # 火车动画（sl 节奏, 40ms/帧）
│   │   ├── CatAct.swift           # 猫动画（后台预渲染 + 插值 + 编码）
│   │   ├── AssetPath.swift        # GIF 路径解析（--gif → CWD → #filePath → Assets/）
│   │   ├── FrameRenderer.swift    # 像素处理 + 编码（核心渲染管线）
│   │   ├── GifLoader.swift        # GIF 解码（ImageIO）+ 裁剪
│   │   ├── Train.swift            # sl D51 火车 art + 烟雾粒子系统
│   │   ├── Overlay.swift          # "Quit: Ctrl+C" 恒定提示
│   │   └── TerminalSize.swift     # 终端尺寸结构体
│   └── SalaryTrainTests/          # 行为测试（SPM 遗留, 未加入 Xcode target）
├── Assets/
│   ├── cat.gif                    # 月薪喵 GIF（131K）
│   └── AppIcon.icns               # 圆角 App 图标
├── CONTEXT.md                     # 项目领域词汇表
└── generate_xcodeproj.py          # 一键重新生成 .xcodeproj
```

## 渲染管线

```
GIF 文件
  ↓ ImageIO 解码
[GifFrame]（CGImage + duration）
  ↓ FrameRenderer.resize（nearest-neighbor 缩放到终端尺寸）
[CGImage]（缩放后）
  ↓ FrameRenderer.renderPixels
    ├─ .outline:  Sobel → NMS → 原色边缘
    ├─ .filled:   不处理（原图）
    ├─ .bw:       亮度阈值化 → 白色剪影
    ├─ .bwDither: Floyd-Steinberg 抖动黑白
    └─ .bwEdge:   detectEyeMask → binarizeAlpha → Sobel+NMS → filterStripeEdges → fillEyes
[UInt8] RGBA 像素缓冲（边缘/处理过）
  ↓ FrameRenderer.interpolatePixelBuffers
    线性 RGBA 插值（边缘模式用阈值二值化，消除鬼影）
[(pixels, width, height)]
  ↓ FrameRenderer.encodeLines / encodeSlashLines
[String] ANSI 终端行
  ↓ Stage.draw（差量重绘 + Quit 提示）
终端输出
```

## 核心算法

### 火车（TrainAct）
移植 canonical sl (Toyoda Masashi) 的 D51 蒸汽机车 + 煤水车 ASCII art（83×10），6 帧车轮旋转动画，烟雾粒子系统（16 图案，每 4 帧生成，漂移消散）。节奏：40ms/帧，1 列/帧。

### 月薪喵渲染（FrameRenderer）

**Sobel + NMS 边缘检测**：3×3 Sobel 算子计算亮度梯度（alpha 加权），量化为 4 个方向（水平/竖直/45°/135°），Non-Maximum Suppression 沿梯度方向比较邻居，只保留局部最大值，2px 带压成 1px。

**bw-edge 模式**（斜线勾边猫）：
1. `detectEyeMask`：扫描蓝色像素（B > R+30, B > G+10）→ 眼睛遮罩
2. `binarizeAlpha`：alpha 二值化，消除抗锯齿
3. `applySobelEdges`：Sobel + NMS，R 通道存储方向码（0=`|`, 1=`/`, 2=`-`, 3=`\`）
4. `filterStripeEdges`：沿梯度方向采样原始亮度图，两侧不透明且亮度差 < stripeThreshold → 抑制（去花纹）
5. `fillEyes`：眼睛遮罩像素 R=255 标记（实心）
6. `encodeSlashLines`：R 0-3 → `/\|-` 斜线，R 255 → `█/▀/▄` 实心块，2 像素/终端行

**Floyd-Steinberg 抖动**：灰度误差按 7/16、3/16、5/16、1/16 扩散到邻居，保留阴影层次。

## 终端技术

- **窗口调整**：`\x1b[8;40;240t` xterm resize 序列，固定 240×40 渲染
- **半块字符**：`\u{2580}`（▀）上半块，`\u{2584}`（▄）下半块，2 像素/终端行
- **真彩色**：`\u{1b}[38;2;R;G;Bm` 前景色，`\u{1b}[48;2;R;G;Bm` 背景色
- **差量重绘**：缓存上一帧，只写变化行，避免闪烁
- **Alt screen**：`\u{1b}[?1049h` 备用屏幕，退出时恢复

## 技术栈

- **语言**：Swift 5.0
- **构建**：Xcode 16（双 Target：SalaryTrain CLI Tool + SalaryTrainApp macOS Application）
- **图像处理**：CoreGraphics + ImageIO（GIF 解码、缩放、像素提取）
- **终端控制**：ANSI escape codes + ioctl (TIOCGWINSZ)
- **启动器**：Cocoa（NSApplication + Process + AppleScript osascript）
- **测试**：XCTest（SPM 遗留测试，未加入 Xcode target）
- **兼容**：macOS 10.15+
