import Foundation
import ARKit
import RealityKit
import ModelIO
import SceneKit
import UIKit

@objc class LidarScanner: NSObject, ARSessionDelegate {
    private var arView: ARView?
    private var session: ARSession?
    private var meshAnchors: [ARMeshAnchor] = []
    private weak var viewController: UIViewController?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    @objc func startScan(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "UNSUPPORTED_DEVICE", message: "Device does not support LiDAR scanning", details: nil))
            return
        }

        arView = ARView(frame: UIScreen.main.bounds)
        viewController?.view.addSubview(arView!)

        session = ARSession()
        session?.delegate = self
        arView?.session = session

        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]

        session?.run(config, options: [.resetTracking, .removeExistingAnchors])
        meshAnchors.removeAll()

        result("Scanning started")
    }

    @objc func stopScan(result: @escaping FlutterResult) {
        session?.pause()
        arView?.removeFromSuperview()
        result("Scanning stopped")
    }

    @objc func exportModel(result: @escaping FlutterResult) {
        guard !meshAnchors.isEmpty else {
            result(FlutterError(code: "NO_DATA", message: "No mesh data available", details: nil))
            return
        }

        let allocator = MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!)
        let asset = MDLAsset(bufferAllocator: allocator)

        for anchor in meshAnchors {
            // Создаем MDLMesh для каждого ARMeshAnchor
            let mdlMesh = MDLMesh(anchor: anchor, device: MTLCreateSystemDefaultDevice()!)
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

            // Презентуем ARView на весь экран
            let arVC = UIViewController()
            arVC.view = arView
            viewController?.present(arVC, animated: true, completion: nil)
            result("Model displayed in AR")
        } catch {
            result(FlutterError(code: "VIEW_FAILED", message: "Failed to load model for AR", details: error.localizedDescription))
        }
    }

    // ARSessionDelegate: Собираем mesh-данные
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Для простоты добавляем обновленные якоря (можно оптимизировать)
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshAnchors.append(meshAnchor)
            }
        }
    }
    
    // Возвращает последний экспортированный .obj (на основе временной папки)
    private func getLastExportedModelURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        let objFiles = files?.filter { $0.pathExtension == "obj" } ?? []
        return objFiles.sorted(by: { $0.path > $1.path }).first
    }
}
