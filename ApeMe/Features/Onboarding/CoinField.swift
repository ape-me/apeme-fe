import SwiftUI
import SpriteKit
import CoreMotion

/// The companies you can buy, as coins drifting behind everything at three depths, all out of
/// focus, the far ones more so. Each depth only bumps into its own layer, so the layers
/// pass over one another like real depth. Tilting the phone leans them all one way; near coins
/// can be grabbed and flicked. Same idea as the apeme.fun landing page, weightless.
struct CoinField: View {
    /// Coins start falling when this turns true, so they arrive after the logo has docked.
    let pouring: Bool
    /// A rect the coins treat as solid, in this view's coordinates (top-left origin).
    var avoid: CGRect = .zero
    @State private var scene = CoinScene()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            SpriteView(scene: scene, options: [.allowsTransparency])
                .onAppear { scene.size = g.size; scene.reduceMotion = reduceMotion; scene.avoid = avoid }
                .onChange(of: g.size) { _, s in scene.size = s }
                .onChange(of: avoid) { _, r in scene.avoid = r }
        }
        .onChange(of: pouring, initial: true) { _, on in if on { scene.pour() } }
        .onDisappear { scene.stopMotion() }
        .accessibilityHidden(true)
    }
}

final class CoinScene: SKScene, SKPhysicsContactDelegate {
    static let symbols = ["nvdax", "applx", "tslax", "openai", "anthropic", "msftx", "amznx", "metax",
                          "googlx", "coinx", "hoodx", "polymarket", "kalshi", "pltrx", "mcdx", "gmex", "neuralink"]

    var reduceMotion = false
    /// SwiftUI coordinates; flipped into the scene's bottom-left space for the obstacle.
    var avoid: CGRect = .zero { didSet { placeObstacle() } }
    private let obstacle = SKNode()
    private let motion = CMMotionManager()
    private var poured = false
    private var grabbed: SKNode?
    private var grabTarget: CGPoint = .zero
    private var lastHaptic = Date.distantPast
    private let tick = UIImpactFeedbackGenerator(style: .soft)

    override init() {
        super.init(size: CGSize(width: 390, height: 360))
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didChangeSize(_ oldSize: CGSize) {
        // A closed box: coins drift inside the screen and bounce off its edges.
        physicsBody = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        physicsBody?.friction = 0.4
        physicsBody?.categoryBitMask = Self.wallBit
        placeObstacle()
    }

    private var avoidInScene: CGRect {
        CGRect(x: avoid.minX, y: size.height - avoid.maxY, width: avoid.width, height: avoid.height)
    }

    private func placeObstacle() {
        if obstacle.parent == nil { addChild(obstacle) }
        guard avoid.width > 0 else { obstacle.physicsBody = nil; return }
        let r = avoidInScene
        let body = SKPhysicsBody(rectangleOf: r.size, center: CGPoint(x: r.midX, y: r.midY))
        body.isDynamic = false
        body.categoryBitMask = Self.wallBit
        body.friction = 0.1
        body.restitution = 0.9
        obstacle.physicsBody = body
    }

    static let wallBit: UInt32 = 1 << 8

    /// Far to near: size, blur, brightness, and how many coins sit at that depth.
    private struct Depth { let scale: CGFloat; let blur: CGFloat; let alpha: CGFloat; let count: Int }
    /// Every depth is out of focus: the coins are backdrop, and the words in front are the point.
    private static let depths = [
        Depth(scale: 0.6, blur: 9, alpha: 0.4, count: 12),
        Depth(scale: 0.8, blur: 6, alpha: 0.55, count: 10),
        Depth(scale: 1, blur: 3.5, alpha: 0.7, count: 8),
    ]

    @MainActor func pour() {
        guard !poured else { return }
        poured = true
        tick.prepare()
        let base = min(max(size.width / 5.2, 60), 86)
        var order = 0
        for (layer, depth) in Self.depths.enumerated() {
            let d = base * depth.scale
            let picks = (Self.symbols.shuffled() + Self.symbols.shuffled()).prefix(depth.count)
            for sym in picks {
                let coin = makeCoin(sym, diameter: d, blur: depth.blur, layer: layer)
                coin.alpha = depth.alpha
                coin.zPosition = CGFloat(layer)
                var spot = CGPoint.zero
                for _ in 0..<12 {   // anywhere but on top of the logo
                    spot = CGPoint(x: .random(in: d / 2...(max(d / 2 + 1, size.width - d / 2))),
                                   y: .random(in: d / 2...(max(d / 2 + 1, size.height - d / 2))))
                    if !avoidInScene.insetBy(dx: -d / 2, dy: -d / 2).contains(spot) { break }
                }
                coin.position = spot
                addChild(coin)
                if !reduceMotion {
                    // Far coins surface first; each one swells in and is given a slow push.
                    let alpha = coin.alpha
                    coin.alpha = 0
                    coin.setScale(0.5)
                    coin.physicsBody?.isDynamic = false
                    let delay = Double(order) * 0.035
                    let pop = SKAction.group([.fadeAlpha(to: alpha, duration: 0.35), .scale(to: 1, duration: 0.45)])
                    pop.timingMode = .easeOut
                    coin.run(.sequence([.wait(forDuration: delay), pop, .run { [weak coin] in
                        guard let body = coin?.physicsBody else { return }
                        body.isDynamic = true
                        body.velocity = Self.drift(depth.scale)
                    }]))
                }
                order += 1
            }
        }
        if !reduceMotion { startMotion() }
    }

    private func makeCoin(_ sym: String, diameter d: CGFloat, blur: CGFloat, layer: Int) -> SKSpriteNode {
        let pad = blur * 3
        let node = SKSpriteNode(texture: SKTexture(image: CoinArt.image(sym, diameter: d, blur: blur)))
        node.size = CGSize(width: d + pad * 2, height: d + pad * 2)
        node.name = layer == Self.depths.count - 1 ? "coin" : "far"
        let body = SKPhysicsBody(circleOfRadius: d / 2 - 1)
        // Each depth only meets its own layer and the walls, so the piles overlap like depth.
        body.categoryBitMask = 1 << UInt32(layer)
        body.collisionBitMask = (1 << UInt32(layer)) | Self.wallBit
        body.contactTestBitMask = layer == Self.depths.count - 1 ? (1 << UInt32(layer)) | Self.wallBit : 0
        body.restitution = 0.9
        body.friction = 0.1
        body.linearDamping = 0.35
        body.angularDamping = 0.6
        // Upright: a sideways Kalshi or an upside-down Apple is harder to recognise, and the
        // logos are the point.
        body.allowsRotation = false
        body.density = 1
        node.physicsBody = body
        return node
    }

    /// A slow push in a random direction; far coins move slower, which sells the depth.
    private static func drift(_ scale: CGFloat) -> CGVector {
        let a = CGFloat.random(in: 0...(2 * .pi)), v = CGFloat.random(in: 18...40) * scale
        return CGVector(dx: cos(a) * v, dy: sin(a) * v)
    }

    private var lastNudge: TimeInterval = 0

    // MARK: Tilt

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            // Portrait: device x is screen x, device y is screen up. Held upright, g.y is about
            // -1, so that part is taken out; only a lean away from upright moves the coins.
            self.physicsWorld.gravity = CGVector(dx: g.x * 3, dy: (g.y + 0.8) * 3)
        }
    }

    func stopMotion() { motion.stopDeviceMotionUpdates() }

    // MARK: Grab and flick

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if let coin = nodes(at: p).first(where: { $0.name == "coin" }) {
            grabbed = coin
            grabTarget = p
            coin.physicsBody?.affectedByGravity = false
            coin.setScale(1.08)
            Haptic.light()
        } else {
            // A tap on empty space kicks the pile.
            for case let coin as SKSpriteNode in children where coin.name == "coin" {
                let dx = coin.position.x - p.x, dy = coin.position.y - p.y
                let dist = max(hypot(dx, dy), 20)
                guard dist < 180 else { continue }
                let k = (180 - dist) / 180 * 45
                coin.physicsBody?.applyImpulse(CGVector(dx: dx / dist * k, dy: abs(dy / dist) * k + k * 0.6))
            }
            Haptic.light()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, grabbed != nil else { return }
        grabTarget = t.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }

    private func release() {
        guard let coin = grabbed else { return }
        coin.physicsBody?.affectedByGravity = true
        coin.run(.scale(to: 1, duration: 0.12))
        grabbed = nil
        // The velocity it was dragged at is kept, which is what makes a flick throw.
    }

    override func update(_ currentTime: TimeInterval) {
        // Keep the field alive: every so often, any coin that has nearly stopped gets a new push.
        if poured, !reduceMotion, currentTime - lastNudge > 1.2 {
            lastNudge = currentTime
            for case let c as SKSpriteNode in children where c !== grabbed {
                guard let b = c.physicsBody, b.isDynamic, hypot(b.velocity.dx, b.velocity.dy) < 10 else { continue }
                b.velocity = Self.drift(c.size.width / 90)
            }
        }
        guard let coin = grabbed, let body = coin.physicsBody else { return }
        // Chase the finger with velocity rather than teleporting, so a held coin still shoves
        // the others out of its way.
        let dx = grabTarget.x - coin.position.x, dy = grabTarget.y - coin.position.y
        body.velocity = CGVector(dx: dx * 18, dy: dy * 18)
    }

    // MARK: Clack

    func didBegin(_ contact: SKPhysicsContact) {
        guard contact.collisionImpulse > 14, Date.now.timeIntervalSince(lastHaptic) > 0.07 else { return }
        lastHaptic = .now
        tick.impactOccurred(intensity: min(1, contact.collisionImpulse / 60))
    }
}

/// A coin face: the company's logo inset in a bevelled rim, drawn once per coin into a texture.
@MainActor
enum CoinArt {
    static func image(_ sym: String, diameter d: CGFloat, blur: CGFloat = 0) -> UIImage {
        // Blurred faces get room to spread; the sprite is sized up by the same padding.
        let r = ImageRenderer(content: Face(sym: sym, d: d).blur(radius: blur).padding(blur * 3))
        r.scale = UIScreen.main.scale
        return r.uiImage ?? UIImage()
    }

    /// The logo's own background, read from its corner. Clear corners get white.
    private static func backdrop(_ img: UIImage) -> (color: Color, bleeds: Bool) {
        guard let cg = img.cgImage else { return (.white, false) }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        // Draw so that the image's (4, 4) pixel lands on our single pixel.
        ctx?.draw(cg, in: CGRect(x: -4, y: -CGFloat(cg.height) + 5, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        guard px[3] > 200 else { return (.white, false) }
        return (Color(red: Double(px[0]) / 255, green: Double(px[1]) / 255, blue: Double(px[2]) / 255), true)
    }

    private struct Face: View {
        let sym: String
        let d: CGFloat
        var body: some View {
            let img = UIImage(named: "coin-" + sym) ?? UIImage()
            let bg = CoinArt.backdrop(img)
            ZStack {
                // Rim: lit from above, darker underneath, like the pucks on the landing page.
                Circle().fill(LinearGradient(colors: [Color(hex: 0x3A3A40), Color(hex: 0x141416)],
                                             startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.02)],
                                                     startPoint: .top, endPoint: .bottom), lineWidth: 1)
                // Full-bleed logos fill the face; logos on a clear background sit inset on white.
                Image(uiImage: img)
                    .resizable().scaledToFit()
                    .frame(width: d * (bg.bleeds ? 0.8 : 0.56), height: d * (bg.bleeds ? 0.8 : 0.56))
                    .frame(width: d * 0.8, height: d * 0.8)
                    .background(bg.color)
                    .clipShape(.circle)
                    .overlay(Circle().stroke(.black.opacity(0.35), lineWidth: 1))
                    .overlay {
                        // A soft gloss across the top of the face.
                        Circle().fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                                     startPoint: .top, endPoint: .center))
                            .frame(width: d * 0.8, height: d * 0.8)
                    }
            }
            .frame(width: d, height: d)
        }
    }
}
