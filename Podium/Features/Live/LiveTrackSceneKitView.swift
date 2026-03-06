//
//  LiveTrackSceneKitView.swift
//  Podium
//
//  3D карта трассы через SceneKit: плоская лента на земле, кружки — сферы.
//

import SwiftUI
import SceneKit

struct LiveTrackSceneKitView: View {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)]
    var locationsVersion: Int = 0

    var body: some View {
        LiveTrackSceneKitRepresentable(
            circuitInfo: circuitInfo,
            drivers: drivers,
            locations: locations,
            locationsVersion: locationsVersion
        )
        .aspectRatio(1.6, contentMode: .fit)
    }
}

private struct LiveTrackSceneKitRepresentable: UIViewRepresentable {
    var circuitInfo: CircuitInfo?
    var drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
    var locations: [Int: (x: Int, y: Int)]
    var locationsVersion: Int

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.scene = buildScene(context: context)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.updateDriverPositions(
            locations: locations,
            circuitInfo: circuitInfo,
            drivers: drivers
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func buildScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        let scale: Float = 20
        let trackPoints = normalizedTrackPoints()
        let trackNode = makeTrackNode(points: trackPoints, scale: scale)
        scene.rootNode.addChildNode(trackNode)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 50
        cameraNode.position = SCNVector3(0, scale * 0.8, scale * 0.9)
        cameraNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cameraNode)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)
        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 600
        directional.position = SCNVector3(scale * 0.5, scale, scale * 0.5)
        directional.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directional)
        let driversNode = SCNNode()
        driversNode.name = "drivers"
        for d in drivers.sorted(by: { $0.position < $1.position }) {
            let sphere = SCNNode()
            sphere.name = "driver_\(d.driverNumber)"
            sphere.geometry = SCNSphere(radius: 0.4)
            sphere.geometry?.firstMaterial?.diffuse.contents = uiColor(forTeam: d.teamName)
            sphere.geometry?.firstMaterial?.specular.contents = UIColor.white
            sphere.geometry?.firstMaterial?.shininess = 0.3
            sphere.position = positionOnTrack(driverNumber: d.driverNumber, position: d.position, scale: scale)
            driversNode.addChildNode(sphere)
        }
        scene.rootNode.addChildNode(driversNode)
        context.coordinator.driversNode = driversNode
        context.coordinator.scale = scale
        return scene
    }

    private func normalizedTrackPoints() -> [(Float, Float)] {
        if let info = circuitInfo, !info.normalizedPathPoints().isEmpty {
            return info.normalizedPathPoints().map { (Float($0.0), Float(1 - $0.1)) }
        }
        return (0..<80).map { i in
            let t = Float(i) / 80 * 2 * .pi
            let u = 0.5 + 0.38 * cos(t)
            let v = 0.5 + 0.38 * sin(t)
            return (u, v)
        }
    }

    private func makeTrackNode(points: [(Float, Float)], scale: Float) -> SCNNode {
        let container = SCNNode()
        let trackWidth: CGFloat = 0.4
        let trackHeight: CGFloat = 0.02
        for i in 0..<points.count {
            let (u1, v1) = points[i]
            let (u2, v2) = points[(i + 1) % points.count]
            let x1 = (u1 - 0.5) * scale
            let z1 = (v1 - 0.5) * scale
            let x2 = (u2 - 0.5) * scale
            let z2 = (v2 - 0.5) * scale
            let dx = x2 - x1
            let dz = z2 - z1
            let len = sqrt(dx * dx + dz * dz)
            guard len > 0.001 else { continue }
            let box = SCNBox(width: trackWidth, height: trackHeight, length: CGFloat(len), chamferRadius: 0)
            box.firstMaterial?.diffuse.contents = UIColor.systemGray5
            box.firstMaterial?.specular.contents = UIColor.white
            box.firstMaterial?.shininess = 0.2
            let node = SCNNode(geometry: box)
            node.position = SCNVector3((x1 + x2) / 2, Float(trackHeight / 2), (z1 + z2) / 2)
            node.eulerAngles.y = atan2(dx, dz)
            container.addChildNode(node)
        }
        return container
    }

    private func positionOnTrack(driverNumber: Int, position: Int, scale: Float) -> SCNVector3 {
        if let (tx, ty) = locations[driverNumber], let info = circuitInfo {
            let (u, v) = info.normalizedUV(trackX: tx, trackY: ty)
            return SCNVector3((Float(u) - 0.5) * scale, 0.3, (Float(1 - v) - 0.5) * scale)
        }
        let spacing: Float = 0.048
        let off = Float(position - 1) * spacing
        var p = (Float(0) - off).truncatingRemainder(dividingBy: 1)
        if p < 0 { p += 1 }
        let (u, v): (Float, Float)
        if let info = circuitInfo {
            let uv = info.pointAtProgress(CGFloat(p))
            u = Float(uv.u)
            v = Float(1 - uv.v)
        } else {
            let a = Double(p) * 2 * .pi
            u = Float(0.5 + 0.38 * cos(a))
            v = Float(0.5 + 0.38 * sin(a))
        }
        return SCNVector3((u - 0.5) * scale, 0.3, (v - 0.5) * scale)
    }

    private func uiColor(forTeam teamName: String) -> UIColor {
        let lower = teamName.lowercased()
        if lower.contains("red bull"), !lower.contains("racing bulls") { return UIColor(red: 20/255, green: 41/255, blue: 72/255, alpha: 1) }
        if lower.contains("racing bulls") || lower.contains("rb ") || lower == "rb" { return UIColor(red: 0/255, green: 56/255, blue: 194/255, alpha: 1) }
        if lower.contains("ferrari") { return UIColor(red: 92/255, green: 0/255, blue: 18/255, alpha: 1) }
        if lower.contains("mclaren") { return UIColor(red: 128/255, green: 64/255, blue: 0/255, alpha: 1) }
        if lower.contains("mercedes") { return UIColor(red: 6/255, green: 126/255, blue: 106/255, alpha: 1) }
        if lower.contains("aston martin") { return UIColor(red: 15/255, green: 67/255, blue: 49/255, alpha: 1) }
        if lower.contains("alpine") { return UIColor(red: 0/255, green: 78/255, blue: 112/255, alpha: 1) }
        if lower.contains("williams") { return UIColor(red: 8/255, green: 33/255, blue: 69/255, alpha: 1) }
        if lower.contains("haas") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        if lower.contains("sauber") || lower.contains("kick") || lower.contains("stake") { return UIColor(red: 102/255, green: 113/255, blue: 117/255, alpha: 1) }
        return UIColor.gray
    }

    final class Coordinator {
        var driversNode: SCNNode?
        var scale: Float = 20
        private let spacing: Float = 0.048

        func updateDriverPositions(
            locations: [Int: (x: Int, y: Int)],
            circuitInfo: CircuitInfo?,
            drivers: [(driverNumber: Int, position: Int, teamColor: Color, teamName: String)]
        ) {
            guard let node = driversNode else { return }
            for d in drivers {
                guard let child = node.childNode(withName: "driver_\(d.driverNumber)", recursively: false) else { continue }
                let pos: SCNVector3
                if let info = circuitInfo, let (tx, ty) = locations[d.driverNumber] {
                    let (u, v) = info.normalizedUV(trackX: tx, trackY: ty)
                    pos = SCNVector3((Float(u) - 0.5) * scale, 0.3, (Float(1 - v) - 0.5) * scale)
                } else if let info = circuitInfo {
                    let off = Float(d.position - 1) * spacing
                    var p = -off.truncatingRemainder(dividingBy: 1)
                    if p < 0 { p += 1 }
                    let uv = info.pointAtProgress(CGFloat(p))
                    pos = SCNVector3((Float(uv.u) - 0.5) * scale, 0.3, (Float(1 - uv.v) - 0.5) * scale)
                } else {
                    let off = Float(d.position - 1) * spacing
                    var p = -off.truncatingRemainder(dividingBy: 1)
                    if p < 0 { p += 1 }
                    let a = Double(p) * 2 * .pi
                    let u = Float(0.5 + 0.38 * cos(a))
                    let v = Float(0.5 + 0.38 * sin(a))
                    pos = SCNVector3((u - 0.5) * scale, 0.3, (v - 0.5) * scale)
                }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                child.position = pos
                SCNTransaction.commit()
            }
        }
    }
}
