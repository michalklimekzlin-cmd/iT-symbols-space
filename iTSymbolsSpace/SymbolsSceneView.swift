import SwiftUI
import SceneKit
import UIKit

/// SceneKit view showing the symbols 'i'Ŧ˚°‰•. as one 3D group.
/// Drag rotates in any direction, pinch zooms, and the group slowly
/// drifts toward the 8 o'clock direction when untouched.
struct SymbolsSceneView: UIViewRepresentable {
    static let symbols = ["'", "i", "'", "Ŧ", "˚", "°", "‰", "•", "."]
    static let colors: [UIColor] = [
        UIColor(white: 0.25, alpha: 1),                       // dark gray
        .black,                                               // black
        UIColor(red: 0.86, green: 0.08, blue: 0.24, alpha: 1), // crimson
        UIColor(red: 0.0, green: 0.39, blue: 0.0, alpha: 1),   // dark green
        UIColor(red: 0.71, green: 0.55, blue: 0.38, alpha: 1), // light brown
        .white
    ]
    static let background = UIColor(red: 0.83, green: 0.68, blue: 0.21, alpha: 1)

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = Self.background
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.rendersContinuously = true

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, Coordinator.defaultDistance)
        scene.rootNode.addChildNode(camera)

        let light = SCNNode()
        light.light = SCNLight()
        light.light?.type = .omni
        light.position = SCNVector3(0, 10, 20)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 600
        scene.rootNode.addChildNode(ambient)

        let group = Self.makeGroup()
        scene.rootNode.addChildNode(group)

        let c = context.coordinator
        c.group = group
        c.camera = camera
        view.delegate = c

        view.addGestureRecognizer(UIPanGestureRecognizer(target: c, action: #selector(Coordinator.pan(_:))))
        view.addGestureRecognizer(UIPinchGestureRecognizer(target: c, action: #selector(Coordinator.pinch(_:))))
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    /// Builds all symbols in one row, centered on the group's origin.
    static func makeGroup() -> SCNNode {
        let group = SCNNode()
        let holder = SCNNode()
        var x: Float = 0
        let spacing: Float = 0.6
        for (i, s) in symbols.enumerated() {
            let text = SCNText(string: s, extrusionDepth: 2)
            text.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            text.flatness = 0.1
            let material = SCNMaterial()
            material.diffuse.contents = colors[i % colors.count]
            material.lightingModel = .blinn
            text.materials = [material]
            let node = SCNNode(geometry: text)
            let (minV, maxV) = node.boundingBox
            let w = Float(maxV.x - minV.x)
            let midY = Float(minV.y + maxV.y) / 2
            node.pivot = SCNMatrix4MakeTranslation(minV.x, 0, 0)
            node.position = SCNVector3(x, -midY, 0)
            holder.addChildNode(node)
            x += w + spacing
        }
        let total = x - spacing
        holder.position = SCNVector3(-total / 2, 0, -1)
        group.addChildNode(holder)
        group.scale = SCNVector3(0.5, 0.5, 0.5)
        return group
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        static let defaultDistance: Float = 28
        var group: SCNNode?
        var camera: SCNNode?
        var isTouching = false
        var lastTime: TimeInterval = 0
        var zoom: Float = 1

        // Idle drift: slow rotation toward 8 o'clock (down-left), radians/sec.
        let idleRate: Float = 0.35

        func rotate(dx: Float, dy: Float) {
            guard let group else { return }
            let angle = sqrt(dx * dx + dy * dy)
            guard angle > 0 else { return }
            // Rotate around an axis in the screen plane, perpendicular to motion.
            let delta = SCNQuaternion.make(axis: SCNVector3(dy, dx, 0), angle: angle)
            group.orientation = SCNQuaternion.multiply(delta, group.orientation)
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            switch g.state {
            case .began: isTouching = true
            case .changed:
                let t = g.translation(in: g.view)
                g.setTranslation(.zero, in: g.view)
                rotate(dx: Float(t.x) * 0.01, dy: Float(t.y) * 0.01)
            default: isTouching = false
            }
        }

        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began: isTouching = true
            case .changed:
                zoom = min(max(zoom * Float(g.scale), 0.3), 3)
                g.scale = 1
                camera?.position.z = Self.defaultDistance / zoom
            default: isTouching = false
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            defer { lastTime = time }
            guard lastTime > 0, !isTouching else { return }
            let dt = Float(time - lastTime)
            // Direction toward 8 o'clock: left and down.
            rotate(dx: -idleRate * dt * 0.5, dy: idleRate * dt * 0.866)
        }
    }
}

private extension SCNQuaternion {
    static func make(axis: SCNVector3, angle: Float) -> SCNQuaternion {
        let len = sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z)
        guard len > 0 else { return SCNVector4(0, 0, 0, 1) }
        let s = sin(angle / 2) / len
        return SCNVector4(axis.x * s, axis.y * s, axis.z * s, cos(angle / 2))
    }

    static func multiply(_ a: SCNQuaternion, _ b: SCNQuaternion) -> SCNQuaternion {
        SCNVector4(
            a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
            a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
            a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
            a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
    }
}
