#if os(macOS)
import Cocoa
import Metal
import MetalKit

/// Transparent click-through overlay window that renders wandering glowing
/// fireflies with bloom for a short duration. No screen capture — pure Metal
/// on a borderless transparent NSWindow above shield level.
///
/// Ported from metal-prototypes/fireflies.
final class FireflyAnimationController: NSObject, MTKViewDelegate {

    private var window: NSWindow?
    private var mtkView: MTKView?
    private var device: MTLDevice?
    private var queue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?

    private var startTime: CFTimeInterval = 0
    private var aspect: Float = 1
    private var duration: CFTimeInterval = 5.0
    private var hideTimer: Timer?

    private struct Uniforms {
        var time: Float = 0
        var aspect: Float = 1
    }
    private var uniforms = Uniforms()

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 position [[position]]; float2 uv; };

    vertex VOut vertex_main(uint vid [[vertex_id]]) {
        VOut o;
        float2 p = float2((vid << 1) & 2, vid & 2);
        o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = float2(p.x, 1.0 - p.y);
        return o;
    }

    struct U { float time; float aspect; };

    float hash(float n) { return fract(sin(n) * 43758.5453); }

    fragment float4 fragment_main(VOut in [[stage_in]], constant U &u [[buffer(0)]]) {
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float t = u.time;
        float cycle = fmod(t, 5.0);
        float3 tint = float3(0.95, 0.85, 0.45);
        float alpha = 0.0;

        const int N = 40;
        for (int i = 0; i < N; i++) {
            float fi = float(i);
            float seed = fi * 17.13;
            float2 p;
            p.x = 0.5 * u.aspect + 0.45 * u.aspect * sin(t * (0.13 + hash(seed) * 0.2) + seed);
            p.y = 0.5 + 0.42 * cos(t * (0.11 + hash(seed + 1.0) * 0.18) + seed * 1.7);
            p.x += 0.04 * sin(t * 1.7 + seed * 3.1);
            p.y += 0.04 * cos(t * 1.9 + seed * 2.3);

            float pulse = 0.5 + 0.5 * sin(t * (1.5 + hash(seed + 2.0)) + seed * 5.0);
            pulse = pow(pulse, 3.0);

            float spawn = hash(seed + 7.0) * 1.0;
            float life = 1.5 + hash(seed + 9.0) * 1.5;
            float age = cycle - spawn;
            float alive = step(0.0, age) * step(age, life);
            float lifeEnv = smoothstep(0.0, 0.25, age) * (1.0 - smoothstep(life - 0.4, life, age));
            pulse *= alive * lifeEnv;

            float d = length(uv - p);
            float core = exp(-d * 250.0);
            float glow = exp(-d * 30.0) * 0.5;
            float v = (core + glow) * pulse;

            alpha = max(alpha, v);
        }

        alpha = clamp(alpha, 0.0, 1.0);
        return float4(tint * alpha, alpha);
    }
    """

    override init() {
        super.init()
    }

    deinit {
        hideTimer?.invalidate()
    }

    /// Shows fireflies across the main screen for ~5 seconds, then hides.
    /// Safe to call re-entrantly: restarts the timer on top of the existing window.
    func play() {
        guard let screen = NSScreen.main else {
            SatiLog.info("Fireflies", "no main screen")
            return
        }

        if window == nil {
            setup(on: screen)
        }
        guard let window = window, let mtkView = mtkView else { return }

        window.setFrame(screen.frame, display: false)
        mtkView.frame = window.contentLayoutRect
        aspect = Float(screen.frame.width / screen.frame.height)
        uniforms.aspect = aspect

        // Arm time BEFORE unpausing the display link so no frame ever renders
        // with a stale startTime (which would land fireflies at a random point
        // in their 5s cycle — visible as a pop on entry).
        startTime = CACurrentMediaTime()
        uniforms.time = 0
        mtkView.isPaused = false
        window.orderFrontRegardless()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hide()
        }
        SatiLog.info("Fireflies", "play (\(Int(duration))s)")
    }

    private func setup(on screen: NSScreen) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            SatiLog.info("Fireflies", "no Metal device")
            return
        }
        self.device = device
        self.queue = device.makeCommandQueue()

        do {
            let lib = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = lib.makeFunction(name: "vertex_main")
            d.fragmentFunction = lib.makeFunction(name: "fragment_main")
            d.colorAttachments[0].pixelFormat = .bgra8Unorm
            d.colorAttachments[0].isBlendingEnabled = true
            d.colorAttachments[0].sourceRGBBlendFactor = .one
            d.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            d.colorAttachments[0].sourceAlphaBlendFactor = .one
            d.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            self.pipeline = try device.makeRenderPipelineState(descriptor: d)
        } catch {
            SatiLog.info("Fireflies", "shader compile failed: \(error)")
            return
        }

        let frame = screen.frame
        let win = NSWindow(contentRect: frame,
                           styleMask: .borderless,
                           backing: .buffered,
                           defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = MTKView(frame: frame, device: device)
        view.preferredFramesPerSecond = 60
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        (view.layer as? CAMetalLayer)?.isOpaque = false
        // Keep paused until play() sets startTime, otherwise the display link
        // can draw one or more frames with stale time.
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.delegate = self

        win.contentView = view
        self.window = win
        self.mtkView = view
        self.aspect = Float(frame.width / frame.height)
        self.uniforms.aspect = self.aspect
    }

    private func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        mtkView?.isPaused = true
        window?.orderOut(nil)
        SatiLog.info("Fireflies", "hidden")
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if size.height > 0 {
            aspect = Float(size.width / size.height)
            uniforms.aspect = aspect
        }
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let rpd = view.currentRenderPassDescriptor,
              let queue = queue,
              let pipeline = pipeline else { return }

        uniforms.time = Float(CACurrentMediaTime() - startTime)
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let cb = queue.makeCommandBuffer(),
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&uniforms,
                             length: MemoryLayout<Uniforms>.stride,
                             index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cb.present(drawable)
        cb.commit()
    }
}
#endif
