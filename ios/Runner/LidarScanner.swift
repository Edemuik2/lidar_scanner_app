import Foundation
import ARKit
import RealityKit
import MetalKit
import ModelIO
import SceneKit
import UIKit

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
            let geometry = ARMeshGeometryToMDLMesh(anchor: anchor, allocator: allocator)
            let submeshes: [MDLSubmesh]? = nil
            let mdlMesh = MDLMesh(scnGeometry: geometry, submeshes: submeshes)
            asset.add(mdlMesh)
        }

        let fileName = "scan-\(Int(Date().timeIntervalSince1970)).obj"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            let scene = SCNScene(mdlAsset: asset)
            let success = scene.write(to: fileURL, options: nil, delegate: nil, progressHandler: nil)
            if success {
                result(fileURL.path)
            } else {
                result(FlutterError(code: "EXPORT_FAILED", message: "Failed to export OBJ", details: nil))
            }
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
            let modelEntity = try ModelEntity.load(contentsOf: modelURL)
            let anchorEntity = AnchorEntity(world: SIMD3<Float>(0, 0, -0.5))
            anchorEntity.addChild(modelEntity)

            let arView = ARView(frame: UIScreen.main.bounds)
            arView.scene.anchors.append(anchorEntity)

            let arVC = UIViewController()
            arVC.view = arView
            viewController?.present(arVC, animated: true, completion: nil)
            result("Model displayed in AR")
        } catch {
            result(FlutterError(code: "VIEW_FAILED", message: "Failed to load model for AR", details: error.localizedDescription))
        }
    }

    private func getLastExportedModelURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        let objFiles = files.filter { $0.pathExtension.lowercased() == "obj" }
        return objFiles.sorted(by: { $0.path > $1.path }).first
    }

    private func ARMeshGeometryToMDLMesh(anchor: ARMeshAnchor, allocator: MTKMeshBufferAllocator) -> SCNGeometry {
        // Упрощённое преобразование ARMeshAnchor в SCNGeometry для SceneKit
        let geometry = SCNGeometry(arMeshAnchor: anchor)
        return geometry
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
