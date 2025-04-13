import Foundation
import ARKit
import RealityKit
import MetalKit
import ModelIO
import SceneKit
import UIKit
import Flutter

@objc class LidarScanner: NSObject {
    private var arView: ARView?
    private var meshAnchors: [ARMeshAnchor] = []
    private weak var viewController: UIViewController?

    @objc init(viewController: UIViewController) {
        self.viewController = viewController
    }

    @objc func startScan(result: @escaping FlutterResult) {
        guard #available(iOS 13.4, *) else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Requires iOS 13.4 or later", details: nil))
            return
        }

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "UNSUPPORTED_DEVICE", message: "Device does not support LiDAR scanning", details: nil))
            return
        }

        let arView = ARView(frame: UIScreen.main.bounds)
        self.arView = arView
        viewController?.view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]

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
        guard #available(iOS 13.4, *) else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Requires iOS 13.4 or later", details: nil))
            return
        }

        guard !meshAnchors.isEmpty else {
            result(FlutterError(code: "NO_DATA", message: "No mesh data available", details: nil))
            return
        }

        guard let device = MTLCreateSystemDefaultDevice() else {
            result(FlutterError(code: "NO_METAL", message: "Metal is not supported on this device", details: nil))
            return
        }

        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)

        for anchor in meshAnchors {
            let mdlMesh = convertToMDLMesh(anchor: anchor, allocator: allocator)
            asset.add(mdlMesh)
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
        guard #available(iOS 13.4, *) else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Requires iOS 13.4 or later", details: nil))
            return
        }

        guard let modelURL = getLastExportedModelURL() else {
            result(FlutterError(code: "NO_MODEL", message: "No exported model found", details: nil))
            return
        }

        do {
            let modelEntity = try ModelEntity.loadModel(contentsOf: modelURL)
            let anchor = AnchorEntity(world: [0, 0, -0.5])
            anchor.addChild(modelEntity)

            let arView = ARView(frame: UIScreen.main.bounds)
            arView.scene.anchors.append(anchor)

            let arVC = UIViewController()
            arVC.view = arView
            viewController?.present(arVC, animated: true, completion: nil)
            result("Model displayed in AR")
        } catch {
            result(FlutterError(code: "VIEW_FAILED", message: "Failed to display model in AR", details: error.localizedDescription))
        }
    }

    private func getLastExportedModelURL() -> URL? {
        let dir = FileManager.default.temporaryDirectory
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "obj" }
                    .sorted { $0.path > $1.path }
                    .first
    }

    @available(iOS 13.4, *)
    private func convertToMDLMesh(anchor: ARMeshAnchor, allocator: MTKMeshBufferAllocator) -> MDLMesh {
        let geometry = anchor.geometry

        let vertexBuffer = geometry.vertices
        let vertexCount = geometry.vertexCount

        let vertexData = Data(bytesNoCopy: vertexBuffer.buffer.contents() + vertexBuffer.offset,
                              count: vertexBuffer.length,
                              deallocator: .none)

        let vertexBufferMDL = allocator.newBuffer(with: vertexData, type: .vertex)

        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: geometry.vertexStride)

        return MDLMesh(vertexBuffer: vertexBufferMDL,
                       vertexCount: vertexCount,
                       descriptor: vertexDescriptor,
                       submeshes: nil)
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
