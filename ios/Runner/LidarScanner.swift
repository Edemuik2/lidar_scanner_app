import Foundation
import ARKit
import RealityKit
import MetalKit
import ModelIO
import SceneKit
import UIKit

@available(iOS 13.4, *)
@objc class LidarScanner: NSObject {
    private var arView: ARView?
    private var meshAnchors: [ARMeshAnchor] = []
    private weak var viewController: UIViewController?

    @objc init(viewController: UIViewController) {
        self.viewController = viewController
    }

    @objc func startScan(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "UNSUPPORTED_DEVICE", message: "Device does not support LiDAR scanning", details: nil))
            return
        }

        let arView = ARView(frame: UIScreen.main.bounds)
        self.arView = arView
        viewController?.view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        meshAnchors.removeAll()

        result("Scanning started")
    }

    @objc func stopScan(result: @escaping FlutterResult) {
        arView?.session.pause()
        arView?.removeFromSuperview()
        arView = nil
        result("Scanning stopped")
    }

    @objc func exportModel(result: @escaping FlutterResult) {
        guard !meshAnchors.isEmpty else {
            result(FlutterError(code: "NO_DATA", message: "No mesh data available", details: nil))
            return
        }

        guard let device = MTLCreateSystemDefaultDevice() else {
            result(FlutterError(code: "NO_METAL", message: "Metal is not supported", details: nil))
            return
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)

        for anchor in meshAnchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            let vertexCount = vertices.count

            let vertexData = Data(bytes: vertices.buffer.contents(), count: vertexCount * MemoryLayout<Float>.size * 3)
            let vertexBuffer = allocator.newBuffer(with: vertexData, type: .vertex)

            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 3)

            let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: vertexCount, descriptor: vertexDescriptor, submeshes: nil)
            asset.add(mesh)
        }

        let fileName = "scan-\(Int(Date().timeIntervalSince1970)).obj"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try asset.export(to: fileURL)
            result(fileURL.path)
        } catch {
            result(FlutterError(code: "EXPORT_FAILED", message: "Failed to export OBJ", details: error.localizedDescription))
        }
    }

    @objc func viewModelInAR(result: @escaping FlutterResult) {
        guard let modelURL = getLastExportedModelURL() else {
            result(FlutterError(code: "NO_MODEL", message: "No exported model found", details: nil))
            return
        }

        do {
            let modelEntity = try ModelEntity.load(contentsOf: modelURL)
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -0.5))
            anchor.addChild(modelEntity)

            let arView = ARView(frame: UIScreen.main.bounds)
            arView.scene.anchors.append(anchor)

            let arVC = UIViewController()
            arVC.view = arView
            viewController?.present(arVC, animated: true, completion: nil)
            result("Model displayed in AR")
        } catch {
            result(FlutterError(code: "VIEW_FAILED", message: "Failed to load model", details: error.localizedDescription))
        }
    }

    private func getLastExportedModelURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        let objFiles = files.filter { $0.pathExtension == "obj" }
        return objFiles.sorted(by: { $0.path > $1.path }).first
    }
}

@available(iOS 13.4, *)
extension LidarScanner: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }
}
