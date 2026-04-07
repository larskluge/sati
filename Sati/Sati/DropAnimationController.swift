#if os(macOS)
import AppKit
import Metal
import MetalKit
import ScreenCaptureKit
import CoreMedia

// MARK: - Metal Shader Source

private let dropShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut drop_vertex(uint vid [[vertex_id]]) {
    VertexOut out;
    float2 pos = float2((vid << 1) & 2, vid & 2);
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    out.texCoord = float2(pos.x, 1.0 - pos.y);
    return out;
}

struct DropUniforms {
    float time;
    float phase;        // 0 = drop, 1 = ripple, 2 = wait
    float impactX;
    float impactY;
    float dropX;
    float dropY;
    float aspectRatio;
    float screenHeight;
};

fragment float4 drop_fragment(VertexOut in [[stage_in]],
                               texture2d<float> screenTex [[texture(0)]],
                               constant DropUniforms &u [[buffer(0)]]) {
    constexpr sampler samp(filter::linear, address::clamp_to_edge);
    float2 uv = in.texCoord;
    float aspect = u.aspectRatio;

    // WAIT — passthrough
    if (u.phase > 1.5) {
        return screenTex.sample(samp, uv);
    }

    // DROP FALLING
    if (u.phase < 0.5) {
        float4 screen = screenTex.sample(samp, uv);

        float2 center = float2(u.dropX, u.dropY);
        float2 diff = uv - center;
        diff.x *= aspect;

        float progress = clamp(u.time, 0.0, 1.0);
        float baseSize = 0.004 + progress * 0.004;

        float2 scaled = float2(diff.x / (baseSize * 0.65), diff.y / (baseSize * 1.1));
        float squeeze = 1.0 + max(-scaled.y, 0.0) * 0.35;
        scaled.x *= squeeze;
        float d = length(scaled);

        if (d < 1.2) {
            float dropAlpha = smoothstep(1.0, 0.3, d);

            float2 hlOff = float2(-0.3, -0.35);
            float hl = 1.0 - smoothstep(0.0, 0.9, length(scaled - hlOff));
            float3 baseColor = float3(0.30, 0.50, 0.82);
            float3 hlColor = float3(0.88, 0.94, 1.0);
            float3 dropColor = mix(baseColor, hlColor, hl * 0.65);

            float shadowDist = length(float2((uv.x - u.impactX) * aspect, uv.y - u.impactY));
            float shadow = exp(-shadowDist * shadowDist * 4000.0) * progress * 0.15;

            float3 result = screen.rgb * (1.0 - shadow);
            result = mix(result, dropColor, dropAlpha * 0.85);
            return float4(result, 1.0);
        }

        float shadowDist = length(float2((uv.x - u.impactX) * aspect, uv.y - u.impactY));
        float shadow = exp(-shadowDist * shadowDist * 4000.0) * progress * 0.15;
        return float4(screen.rgb * (1.0 - shadow), 1.0);
    }

    // RIPPLE
    float2 impact = float2(u.impactX, u.impactY);
    float2 diff = uv - impact;
    diff.x *= aspect;
    float r = length(diff);
    float t = u.time;

    float speed    = 0.55;
    float freq     = 22.0;
    float decay    = 4.5;
    float amp      = 1.0;

    float localTime = t - r / speed;

    if (localTime < 0.0) {
        return screenTex.sample(samp, uv);
    }

    float envelope = amp * exp(-decay * localTime)
                   / sqrt(max(r * 12.0, 0.15))
                   * exp(-0.8 * t);

    envelope *= smoothstep(0.0, 0.06, localTime);

    float sinTerm = sin(freq * localTime);
    float cosTerm = cos(freq * localTime);
    float height  = envelope * sinTerm;

    float dheight = envelope / speed * (-freq * cosTerm + decay * sinTerm);

    float splash = exp(-t * 16.0) * exp(-r * r * 1500.0) * 1.5;
    float dsplash = exp(-t * 16.0) * exp(-r * r * 1500.0) * (-2.0 * r * 1500.0) * 1.5;
    height  += splash;
    dheight += dsplash;

    float2 dir = r > 0.001 ? diff / r : float2(0.0);
    dir.x /= aspect;

    float refractionStrength = 0.0012;
    float2 displacement = dir * dheight * refractionStrength;

    float2 refractedUV = clamp(uv + displacement, float2(0.0), float2(1.0));
    float4 screen = screenTex.sample(samp, refractedUV);

    float caustic = clamp(height * height * 4.0, 0.0, 0.12);
    screen.rgb += caustic * float3(0.7, 0.85, 1.0);
    screen.rgb -= clamp(-height * 1.2, 0.0, 0.06);

    return float4(screen.rgb, 1.0);
}
"""

// MARK: - Animation State

private enum DropAnimPhase {
    case falling(start: Double, fromY: Float, toX: Float, toY: Float)
    case rippling(start: Double, x: Float, y: Float)
    case done
}

// MARK: - Uniforms

private struct DropUniforms {
    var time: Float = 0
    var phase: Float = 0
    var impactX: Float = 0.5
    var impactY: Float = 0.5
    var dropX: Float = 0.5
    var dropY: Float = 0.5
    var aspectRatio: Float = 1.0
    var screenHeight: Float = 900
}

// MARK: - Renderer

private final class DropRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    var uniforms = DropUniforms()
    var currentTexture: MTLTexture?
    var phase: DropAnimPhase = .done
    var onFinished: (() -> Void)?
    private let textureLock = NSLock()

    let fallDuration: Double = 0.32
    let rippleDuration: Double = 3.0

    init(device: MTLDevice, pixelFormat: MTLPixelFormat, aspectRatio: Float, screenHeight: Float) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        let library = try! device.makeLibrary(source: dropShaderSource, options: nil)
        let vertexFunc = library.makeFunction(name: "drop_vertex")!
        let fragmentFunc = library.makeFunction(name: "drop_fragment")!

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertexFunc
        desc.fragmentFunction = fragmentFunc
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = false

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

        uniforms.aspectRatio = aspectRatio
        uniforms.screenHeight = screenHeight

        super.init()
    }

    func setTexture(_ texture: MTLTexture) {
        textureLock.lock()
        currentTexture = texture
        textureLock.unlock()
    }

    func startDrop() {
        let tx = Float.random(in: 0.30...0.70)
        let ty = Float.random(in: 0.40...0.65)
        phase = .falling(start: CACurrentMediaTime(), fromY: 0.25, toX: tx, toY: ty)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        textureLock.lock()
        let tex = currentTexture
        textureLock.unlock()

        guard let tex = tex,
              let drawable = view.currentDrawable,
              let passDesc = view.currentRenderPassDescriptor else { return }

        let now = CACurrentMediaTime()

        switch phase {
        case .falling(let start, let fromY, let toX, let toY):
            let elapsed = now - start
            let progress = min(Float(elapsed / fallDuration), 1.0)
            let gravityProgress = progress * progress
            let currentY = fromY + (toY - fromY) * gravityProgress

            uniforms.phase = 0
            uniforms.time = progress
            uniforms.dropX = toX
            uniforms.dropY = currentY
            uniforms.impactX = toX
            uniforms.impactY = toY

            if progress >= 1.0 {
                phase = .rippling(start: now, x: toX, y: toY)
            }

        case .rippling(let start, let x, let y):
            let elapsed = Float(now - start)
            uniforms.phase = 1
            uniforms.time = elapsed
            uniforms.impactX = x
            uniforms.impactY = y

            if Double(elapsed) >= rippleDuration {
                phase = .done
                DispatchQueue.main.async { [weak self] in
                    self?.onFinished?()
                }
                return
            }

        case .done:
            return
        }

        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(tex, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DropUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}

// MARK: - Stream Output Handler

private final class DropStreamHandler: NSObject, SCStreamOutput {
    let device: MTLDevice
    let renderer: DropRenderer
    private var textureCache: CVMetalTextureCache?

    init(device: MTLDevice, renderer: DropRenderer) {
        self.device = device
        self.renderer = renderer
        super.init()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let cache = textureCache else { return }

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, pixelBuffer, nil,
            .bgra8Unorm, width, height, 0, &cvTexture
        )

        guard status == kCVReturnSuccess, let cvTex = cvTexture,
              let metalTexture = CVMetalTextureGetTexture(cvTex) else { return }

        renderer.setTexture(metalTexture)
    }
}

// MARK: - Public Controller

final class DropAnimationController {
    private var window: NSWindow?
    private var mtkView: MTKView?
    private var renderer: DropRenderer?
    private var streamHandler: DropStreamHandler?
    private var stream: SCStream?

    func play() {
        // Re-entry guard: if a previous animation is still in flight, tear it
        // down before starting a new one. Otherwise the old SCStream leaks and
        // keeps capturing the screen forever (~10% CPU, no visible animation,
        // because the old renderer's onFinished will tear down the *new*
        // stream and leave the old one orphaned).
        if stream != nil || window != nil {
            tearDown()
        }

        guard let device = MTLCreateSystemDefaultDevice(),
              let screen = NSScreen.main else { return }

        let frame = screen.frame
        let aspectRatio = Float(frame.width / frame.height)

        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.hasShadow = false

        let view = MTKView(frame: frame, device: device)
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        (view.layer as? CAMetalLayer)?.isOpaque = false

        let ren = DropRenderer(
            device: device,
            pixelFormat: view.colorPixelFormat,
            aspectRatio: aspectRatio,
            screenHeight: Float(frame.height)
        )
        ren.onFinished = { [weak self, weak ren] in
            guard let self = self, let ren = ren, self.renderer === ren else { return }
            self.tearDown()
        }
        view.delegate = ren

        win.contentView = view
        win.orderFrontRegardless()

        self.window = win
        self.mtkView = view
        self.renderer = ren

        let handler = DropStreamHandler(device: device, renderer: ren)
        self.streamHandler = handler

        startCapture(screen: screen, handler: handler) { [weak ren] in
            ren?.startDrop()
        }
    }

    private func startCapture(screen: NSScreen, handler: DropStreamHandler, onReady: @escaping () -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard let display = content.displays.first(where: {
                    CGDisplayIsMain(UInt32($0.displayID)) != 0
                }) ?? content.displays.first else { return }

                let myPID = ProcessInfo.processInfo.processIdentifier
                let excludedApps = content.applications.filter { $0.processID == myPID }

                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApps,
                    exceptingWindows: []
                )

                let config = SCStreamConfiguration()
                config.width = Int(display.width) * 2
                config.height = Int(display.height) * 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.queueDepth = 3
                config.showsCursor = false

                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(handler, type: .screen,
                    sampleHandlerQueue: .global(qos: .userInteractive))
                try await stream.startCapture()
                self.stream = stream

                // Give capture a moment to deliver the first frame
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onReady()
                }
            } catch {
                SatiLog.info("DropAnimation", "screen capture failed: \(error)")
                self.tearDown()
            }
        }
    }

    private func tearDown() {
        if let stream = stream {
            Task { try? await stream.stopCapture() }
        }
        stream = nil
        streamHandler = nil
        renderer = nil
        mtkView = nil
        window?.orderOut(nil)
        window = nil
    }
}
#endif
