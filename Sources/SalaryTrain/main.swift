import Foundation

func previewTrain() {
    let w = D51_LENGTH
    var ruler = ""
    for i in 0..<w { ruler += "\(i % 10)" }
    print("D51 width=\(w) height=\(D51_HEIGHT) patterns=\(D51_PATTERNS)")
    print(ruler)
    for line in d51Sprite(wheelPattern: 0) { print(line) }
    print("--- wheel cycle ---")
    for p in 0..<D51_PATTERNS {
        print("pattern \(p):")
        for line in d51Sprite(wheelPattern: p) { print(line) }
    }
}

struct CLIOptions {
    var gifPath: String?
    var speed: Double = 30
    // 月薪喵渲染模式旗标（最后指定的覆盖）。
    var filled: Bool = false
    var outline: Bool = false
    var bw: Bool = false
    var dither: Bool = false
    var bwEdge: Bool = false
    var edgeThreshold: Int? = nil
    var bwThreshold: Int? = nil
    var stripeThreshold: Int? = nil
    var mode: Mode = .show
}

enum Mode {
    case show
    case previewTrain
    case dumpFrame
    case catOnly
}

/// 月薪喵动画预设参数表（旗标解析后合成一份 RenderParams）。
let presetTable = """
月薪喵动画预设参数表（默认模式 bw-edge，插帧 1x）：
  bw-edge   (默认) 斜线勾边猫,  --bw-edge  --edge-threshold 200
  outline           Sobel+NMS 边缘线稿,  --outline  --edge-threshold 60
  filled            全彩填充,            --filled
  bw                取模黑白白色剪影,     --bw  --bw-threshold 128
  bw-dither         Floyd-Steinberg 抖动黑白, --bw --dither  --bw-threshold 128
"""

func parseArgs() -> CLIOptions {
    var opts = CLIOptions()
    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0
    while i < args.count {
        let a = args[i]
        switch a {
        case "--gif":
            i += 1
            if i < args.count { opts.gifPath = args[i] }
        case "--speed":
            i += 1
            if i < args.count, let v = Double(args[i]) { opts.speed = v }
        case "--filled":
            opts.filled = true
            opts.bw = false
            opts.dither = false
            opts.bwEdge = false
            opts.outline = false
        case "--outline":
            opts.outline = true
            opts.filled = false
            opts.bw = false
            opts.bwEdge = false
            opts.dither = false
        case "--bw":
            opts.bw = true
            opts.filled = false
            opts.bwEdge = false
        case "--dither":
            opts.dither = true
            opts.bw = true
            opts.filled = false
            opts.bwEdge = false
        case "--bw-edge":
            opts.bwEdge = true
            opts.filled = false
            opts.bw = false
            opts.dither = false
        case "--edge-threshold":
            i += 1
            if i < args.count, let v = Int(args[i]) { opts.edgeThreshold = v }
        case "--bw-threshold":
            i += 1
            if i < args.count, let v = Int(args[i]) { opts.bwThreshold = v }
        case "--stripe-threshold":
            i += 1
            if i < args.count, let v = Int(args[i]) { opts.stripeThreshold = v }
        case "--preview-train":
            opts.mode = .previewTrain
        case "--dump-frame":
            opts.mode = .dumpFrame
        case "--cat-only":
            opts.mode = .catOnly
        case "-h", "--help":
            print("SalaryTrain — sl 蒸汽火车 + 月薪喵动画")
            print("用法: SalaryTrain [--gif <path>] [--speed <列/秒>] [模式旗标] [阈值]")
            print("       SalaryTrain --preview-train | --dump-frame | --cat-only")
            print("")
            print(presetTable)
            print("--outline         Sobel+NMS 边缘线稿（旧默认模式）")
            print("--filled          画填充月薪喵")
            print("--bw              取模黑白（白色剪影 on 黑底）")
            print("--dither          配合 --bw：Floyd-Steinberg 抖动黑白")
            print("--bw-edge         斜线勾边猫（默认模式，/\\|- 画轮廓，眼睛实心，去花纹）")
            print("--edge-threshold  Sobel 边缘阈值（outline 默认 60, bw-edge 默认 200，越小边缘越多）")
            print("--stripe-threshold 花纹抑制阈值（bw-edge 默认 120，越小去花纹越多）")
            print("--bw-threshold    黑白亮度阈值，默认 128（越小白色越多）")
            print("默认模式 bw-edge（斜线勾边猫，插帧 1x）。")
            print("Ctrl+C 退出。")
            exit(0)
        default:
            break
        }
        i += 1
    }
    return opts
}

let opts = parseArgs()

/// 旗标 → RenderParams（预设参数的代码化）。
func resolveParams(_ o: CLIOptions) -> RenderParams {
    if o.bwEdge {
        var p = RenderParams.bwEdge
        if let et = o.edgeThreshold { p.edgeThreshold = et }
        if let st = o.stripeThreshold { p.stripeThreshold = st }
        return p
    }
    if o.bw {
        if o.dither {
            var p = RenderParams.bwDither
            if let bt = o.bwThreshold { p.bwThreshold = bt }
            return p
        }
        var p = RenderParams.bw
        if let bt = o.bwThreshold { p.bwThreshold = bt }
        return p
    }
    if o.outline {
        var p = RenderParams.outline
        if let et = o.edgeThreshold { p.edgeThreshold = et }
        return p
    }
    if o.filled {
        return .filled
    }
    // 默认模式：bwEdge（斜线勾边猫）
    var p = RenderParams.bwEdge
    if let et = o.edgeThreshold { p.edgeThreshold = et }
    if let st = o.stripeThreshold { p.stripeThreshold = st }
    return p
}

switch opts.mode {
case .previewTrain:
    previewTrain()
    exit(0)
case .dumpFrame:
    let url = AssetPath.resolveGif(opts.gifPath)
    var frames = GifLoader.loadGif(at: url)
    frames = GifLoader.trim(frames)
    guard let first = frames.first else { fputs("no frames\n", stderr); exit(1) }
    let term = TerminalSize(columns: 240, rows: 40)
    let src = (first.image.width, first.image.height)
    let target = FrameRenderer.fitSize(source: src, terminal: term, reservedRows: term.rows / 2, verticalPixelsPerRow: 2)
    let resized = FrameRenderer.resize(first.image, to: target)
    let p = resolveParams(opts)
    print("frame \(first.image.width)x\(first.image.height) -> \(target) mode=\(p.mode) edge=\(p.edgeThreshold) bw=\(p.bwThreshold)")
    let lines = FrameRenderer.render(resized, params: p)
    for l in lines { print(l) }
    exit(0)
default:
    break
}

let gifURL = AssetPath.resolveGif(opts.gifPath)
var frames = GifLoader.loadGif(at: gifURL)
frames = GifLoader.trim(frames)

let catParams = resolveParams(opts)

if opts.mode == .catOnly {
    let stage = Stage()
    let catAct = CatAct(stage: stage, frames: frames, params: catParams)
    let show = Show(stage: stage, trainAct: TrainAct(stage: stage), catAct: catAct)
    show.runCatOnly()
    exit(0)
}

let stage = Stage()
let trainAct = TrainAct(stage: stage, speed: opts.speed)
let catAct = CatAct(stage: stage, frames: frames, params: catParams)
let show = Show(stage: stage, trainAct: trainAct, catAct: catAct)
show.run()
