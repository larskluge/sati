#if os(macOS)
import AppKit
import Metal
import MetalKit

private let vignetteShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float2 mousePos;
    float2 screenSize;
    float  radius;
    float  softness;
    float  opacity;
    float  spread;       // 0=default vignette, 1=covers ~80% of screen
};

vertex VertexOut vertex_main(uint vid [[vertex_id]]) {
    float2 pos = float2((vid << 1) & 2, vid & 2);
    VertexOut out;
    out.position = float4(pos * 2.0 - 1.0, 0.0, 1.0);
    out.texCoord = float2(pos.x, 1.0 - pos.y);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                               constant Uniforms &u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 pixelPos = in.position.xy;

    float dist = length(pixelPos - u.mousePos);
    float cursorMask = smoothstep(u.radius, u.radius + u.softness, dist);

    float alpha = 0.0;
    float3 tint = float3(0.0);

    // spread: 0 = default edge vignette, 1 = covers ~80% of screen
    float s = u.spread;
    float vigStart = mix(0.25, 0.02, s);    // inner edge moves inward
    float vigEnd   = mix(0.55, 0.15, s);    // outer edge moves inward

    float2 vig = uv - 0.5;
    float vigDist = dot(vig, vig);
    float vigAmount = smoothstep(vigStart, vigEnd, vigDist);
    alpha = max(alpha, vigAmount * mix(0.6, 0.85, s));

    float edgeStart = mix(0.35, 0.08, s);
    float edgeEnd   = mix(0.52, 0.20, s);
    float edgeFade = smoothstep(edgeStart, edgeEnd, vigDist);
    alpha = max(alpha, edgeFade * 0.85);

    float2 d = abs(uv - 0.5) * 2.0;
    float cornerDist = pow(d.x, 4.0) + pow(d.y, 4.0);
    float cornerDark = smoothstep(mix(0.7, 0.1, s), mix(1.1, 0.4, s), cornerDist);
    alpha = max(alpha, cornerDark);

    float scanline = sin(in.position.y * 1.5) * 0.5 + 0.5;
    float scanAlpha = (1.0 - scanline) * 0.08 * vigAmount;
    alpha = max(alpha, scanAlpha);

    tint = float3(0.12, 0.06, 0.0) * vigAmount;

    alpha *= cursorMask;
    tint *= cursorMask;

    alpha *= u.opacity;
    tint *= u.opacity;

    return float4(tint, alpha);
}
"""

private struct VignetteUniforms {
    var mousePos: SIMD2<Float> = .zero
    var screenSize: SIMD2<Float> = .zero
    var radius: Float = 80.0
    var softness: Float = 60.0
    var opacity: Float = 0.0
    var spread: Float = 0.0
}

private class VignetteRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    var uniforms = VignetteUniforms()

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        let library = try! device.makeLibrary(source: vignetteShaderSource, options: nil)
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "vertex_main")!
        desc.fragmentFunction = library.makeFunction(name: "fragment_main")!
        desc.colorAttachments[0].pixelFormat = pixelFormat
        desc.colorAttachments[0].isBlendingEnabled = true
        desc.colorAttachments[0].sourceRGBBlendFactor = .one
        desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        desc.colorAttachments[0].sourceAlphaBlendFactor = .one
        desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.screenSize = SIMD2<Float>(Float(size.width), Float(size.height))
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let passDesc = view.currentRenderPassDescriptor else { return }

        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VignetteUniforms>.size, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }
}

final class VignetteOverlayController {
    private var window: NSWindow?
    private var mtkView: MTKView?
    private var renderer: VignetteRenderer?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var fadeTimer: Timer?
    private var spreadTimer: Timer?
    private var lastMouseMoveTime: CFAbsoluteTime = 0
    private var targetSpread: Float = 0.0
    private var backingScale: CGFloat = 2.0
    private let idleGrowDelay: TimeInterval = 3.0   // seconds before spread starts growing
    private let idleGrowDuration: TimeInterval = 15.0 // seconds to reach full spread
    private let shrinkDuration: TimeInterval = 0.5    // seconds to shrink back

    private func setup() {
        guard window == nil else { return }
        guard let device = MTLCreateSystemDefaultDevice(),
              let screen = NSScreen.main else { return }

        let frame = screen.frame
        backingScale = screen.backingScaleFactor

        let w = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.ignoresMouseEvents = true
        w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.hasShadow = false

        let view = MTKView(frame: frame, device: device)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.layer?.isOpaque = false
        (view.layer as? CAMetalLayer)?.isOpaque = false

        let r = VignetteRenderer(device: device, pixelFormat: view.colorPixelFormat)
        r.uniforms.screenSize = SIMD2<Float>(
            Float(frame.width * backingScale),
            Float(frame.height * backingScale)
        )
        r.uniforms.radius = Float(80.0 * backingScale)
        r.uniforms.softness = Float(60.0 * backingScale)
        r.uniforms.opacity = 0.0

        view.delegate = r
        w.contentView = view

        self.window = w
        self.mtkView = view
        self.renderer = r

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] _ in
            self?.updateMousePosition()
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateMousePosition()
            return event
        }
    }

    func fadeIn(duration: TimeInterval) {
        setup()
        guard let renderer = renderer, let mtkView = mtkView, let window = window else { return }

        renderer.uniforms.opacity = 0.0
        renderer.uniforms.spread = 0.0
        lastMouseMoveTime = CFAbsoluteTimeGetCurrent()
        window.orderFrontRegardless()
        updateMousePosition()

        fadeTimer?.invalidate()
        let startTime = CFAbsoluteTimeGetCurrent()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self, let renderer = self.renderer, let mtkView = self.mtkView else {
                timer.invalidate()
                return
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let t = Float(min(elapsed / duration, 1.0))
            let eased = t * t * (3.0 - 2.0 * t)
            renderer.uniforms.opacity = eased
            mtkView.needsDisplay = true
            if t >= 1.0 {
                timer.invalidate()
                self.fadeTimer = nil
                self.startSpreadTimer()
            }
        }
    }

    private func startSpreadTimer() {
        spreadTimer?.invalidate()
        spreadTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self = self, let renderer = self.renderer, let mtkView = self.mtkView else {
                timer.invalidate()
                return
            }
            let now = CFAbsoluteTimeGetCurrent()
            let idleTime = now - self.lastMouseMoveTime

            if idleTime > self.idleGrowDelay {
                // Grow spread toward 1.0
                let growProgress = (idleTime - self.idleGrowDelay) / self.idleGrowDuration
                self.targetSpread = Float(min(growProgress, 1.0))
            } else {
                // Shrink back to 0
                self.targetSpread = 0.0
            }

            let current = renderer.uniforms.spread
            let diff = self.targetSpread - current
            if abs(diff) > 0.001 {
                let speed: Float = diff > 0 ? 1.0 / Float(self.idleGrowDuration * 30) : Float(1.0 / (self.shrinkDuration * 30))
                renderer.uniforms.spread = current + (diff > 0 ? speed : -min(abs(diff), speed * 3))
                renderer.uniforms.spread = max(0, min(1, renderer.uniforms.spread))
                mtkView.needsDisplay = true
            }
        }
    }

    func fadeOut(duration: TimeInterval) {
        guard let renderer = renderer, let mtkView = mtkView else {
            hide()
            return
        }

        fadeTimer?.invalidate()
        let startOpacity = renderer.uniforms.opacity
        let startTime = CFAbsoluteTimeGetCurrent()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self = self, let renderer = self.renderer, let mtkView = self.mtkView else {
                timer.invalidate()
                return
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let t = Float(min(elapsed / duration, 1.0))
            let eased = t * t * (3.0 - 2.0 * t)
            renderer.uniforms.opacity = startOpacity * (1.0 - eased)
            mtkView.needsDisplay = true
            if t >= 1.0 {
                timer.invalidate()
                self.fadeTimer = nil
                self.hide()
            }
        }
    }

    func hide() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        spreadTimer?.invalidate()
        spreadTimer = nil
        renderer?.uniforms.spread = 0.0
        window?.orderOut(nil)
    }

    private func updateMousePosition() {
        guard let renderer = renderer, let mtkView = mtkView else { return }
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.main else { return }

        let x = (mouseLocation.x - screen.frame.origin.x) * backingScale
        let y = (screen.frame.height - (mouseLocation.y - screen.frame.origin.y)) * backingScale

        renderer.uniforms.mousePos = SIMD2<Float>(Float(x), Float(y))
        lastMouseMoveTime = CFAbsoluteTimeGetCurrent()
        mtkView.needsDisplay = true
    }
}
#endif
