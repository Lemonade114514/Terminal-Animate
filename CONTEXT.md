# SalaryTrain

一场终端演出：蒸汽火车从右向左驶过后，月薪喵 GIF 居中循环播放，Ctrl+C 退出。

## 编排

**Show**:
一场演出。按固定顺序编排 TrainAct 与 CatAct，两幕之间清屏，全程响应 SIGINT。
_Avoid_: App, Program, Loop

**Act**:
演出的一幕。协议：start() 进幕、step(elapsed:) 推进一帧、isFinished 判定终态。
持有 Stage 引用，内部读 size、调 draw。
_Avoid_: Scene, Phase

**TrainAct**:
第一幕。蒸汽火车从右向左滚动，含车身/飘烟/车轮。
isFinished = trainX + width < 0。
_Avoid_: ScrollArt, TrainAnimation

**CatAct**:
第二幕。cat.gif 逐帧循环播放，isFinished 恒 false，靠 Show.running 退出。
_Avoid_: GifAct, CatAnimation

**Show.running**:
演出是否进行中。DispatchSourceSignal 捕获 SIGINT 置 false，主循环据此退出。

**tick**:
主循环心跳间隔，固定 ~16ms（60fps）。两幕共用。elapsed ≈ 0.016。

## 舞台

**Stage**:
演出环境。封装 alt screen、强制黑底、隐藏光标、清屏、终端尺寸、差量重绘。
_Avoid_: Terminal, Screen, Canvas

**Stage.size**:
当前终端 (cols, rows)，每次访问实时 ioctl 读取。Act 读取以适配画面，resize 立即生效。

**Stage.draw**:
差量重绘。缓存上一帧，只写变化行，避免闪烁/tearing。

**Frame buffer**:
一帧的字符串行数组，Act 产出，Stage.draw 消费。

## 火车部件（TrainAct 内部概念，非独立类型）

**Body**:
静态多行彩色 ASCII 车身图样，每帧不变。

**Smoke**:
烟囱上方按时钟/随机生成的飘动字符（. o O @ *），向上飘散。

**Wheels**:
底部车轮，按相位轮换字符（○ ◐ ◓ ◑ ◒）模拟转动。

**TrainAct.speed**:
火车横向速度，单位 列/秒，默认 30。

## GIF 装载与渲染

**GifFrame**:
GIF 解码出的原始位图帧（CGImage + duration）。数据层。
_Avoid_: RawFrame, ImageFrame

**RenderedFrame**:
已缩放并转成终端字符串行的一帧（[String] + duration）。表现层。
_Avoid_: ScreenFrame, DisplayFrame

**Trim**:
GIF 装载时裁掉帧间透明边距的预处理。

**AssetPath**:
CatAct 装载 GIF 的路径解析策略，--gif 参数 → CWD → #filePath 源码树 fallback。

## 月薪喵渲染预设

**RenderMode**:
月薪喵动画的渲染模式枚举：filled（全彩填充）/ outline（Sobel+NMS 边缘线稿）/ bw（取模黑白白色剪影）/ bwDither（Floyd-Steinberg 抖动黑白）/ bwEdge（黑底白线勾边，Sobel+NMS 边缘统一白，内部留空）。SalaryTrainCore 公共类型。
_Avoid_: EdgeMode, RenderStyle

**RenderParams**:
预设参数包（mode + edgeThreshold + bwThreshold）。每条 static let 是一份预设：.outline（edge 60）/ .filled / .bw（bw 128）/ .bwDither（bw 128）/ .bwEdge（edge 100）。CatAct 持有一份，CLI 旗标经 resolveParams() 合成。
_Avoid_: RenderConfig, RenderOptions

**bw**:
取模黑白模式。亮度 ≥ bwThreshold 的像素画白（不透明），其余透明，得到白色剪影 on 黑底。透明像素视为 Y=0，外轮廓被切干净。--bw 旗标开启。

**bwDither**:
Floyd-Steinberg 抖动黑白模式。把灰度误差按 7/16、3/16、5/16、1/16 扩散到邻居再二值化，保留阴影层次，像 OLED 取模点阵。--bw --dither 旗标组合开启。

**bwEdge**:
斜线勾边模式。alpha 二值化后 Sobel+NMS 检测边缘，边缘像素在 R 通道存储方向码（0=|, 1=/, 2=-, 3=\），由 encodeSlashLines 按 2:1 像素映射（和半块模式一致）画成白色 /\|- 字符。黑底纯白斜线轮廓，内部留空，像 ASCII 线稿画猫咪。--bw-edge 旗标开启，--edge-threshold 调边缘阈值（默认 200）。encodeSlashLines 每对像素行 (y, y+1) 合并为 1 终端行，任一行有边缘即画斜线。

**NMS**:
Non-Maximum Suppression。Sobel 后的细化步骤：沿梯度方向比较邻居，只保留局部最大幅值的像素，把 2px 宽的边缘带压成 1px。硬边缘（如外轮廓）会因两像素幅值相等触发 tie-break：保留左侧/顶部像素。outline 和 bwEdge 路径都走 NMS。

**renderPixels**:
像素处理 seam。解码 CGImage → RGBA，按 RenderParams 模式变换（Sobel+NMS / bw / dither / edge），返回处理后的像素缓冲。纯函数，无 I/O，是 FrameRenderer 的可测接口。
_Avoid_: processImage, transformPixels

**encodeLines**:
编码 seam（半块模式）。RGBA 像素缓冲 → ANSI 半块字符串行数组，2 像素/行。与 renderPixels 拆分后，像素级行为可在 renderPixels 上测试，不依赖 ANSI 编码。
_Avoid_: renderToLines, buildOutput

**encodeSlashLines**:
编码 seam（斜线模式，bwEdge 专用）。RGBA 像素缓冲 → ANSI 斜线字符串行数组，2 像素/行（和 encodeLines 一致）。每对像素行 (y, y+1) 合并为 1 终端行：任一行有边缘（alpha≥200）→ 用该像素 R 通道方向码画 |（竖边）/（斜边）-（横边）\（反斜边），白色 on 黑底；都有 → 取顶部。
_Avoid_: renderToLines, buildOutput

**edgeThreshold**:
Sobel 边缘阈值，outline 默认 60、bwEdge 默认 200。越小边缘越多。--edge-threshold 旗标覆盖（仅在明确传入时覆盖预设）。

**bwThreshold**:
黑白亮度阈值，bw / bwDither 模式用，默认 128。越小白色越多。--bw-threshold 旗标覆盖。

## 恒定提示层

**Overlay**:
恒定提示层（纯函数，可测）。负责左下角 "Quit: Ctrl+C" 提示的生成与盖印。Stage.draw 每帧调 stampQuitHint 把提示盖到 buffer 最后一行。
_Avoid_: Hud, StatusLine, Footer

**stampQuitHint**:
把传入 buffer 的最后一行替换为 quitHintRow(cols:)，其余行不动。Stage.draw 在 diff 前调用，保证提示恒定显示。
_Avoid_: drawHint, renderFooter
