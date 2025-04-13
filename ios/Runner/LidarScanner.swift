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

    // Инициализатор с передачей root view контроллера
    @objc init(viewController: UIViewController) {
        self.viewController = viewController
    }

    // Запуск сканирования
    @objc func startScan(result: @escaping FlutterResult) {
        if #available(iOS 13.4, *) {
            guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
                result(FlutterError(code: "UNSUPPORTED_DEVICE", message: "Device does not support LiDAR scanning", details: nil))
                return
            }
            
            // Инициализируем ARView
            let arView = ARView(frame: UIScreen.main.bounds)
            self.arView = arView
            viewController?.view.addSubview(arView)
            
            // Настраиваем AR-сессию
            let configuration = ARWorldTrackingConfiguration()
            configuration.sceneReconstruction = .mesh
            configuration.environmentTexturing = .automatic
            configuration.planeDetection = [.horizontal, .vertical]
            
            arView.session.delegate = self
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            meshAnchors.removeAll()
            
            result("Scanning started")
        } else {
            result(FlutterError(code: "IOS_TOO_LOW", message: "iOS 13.4 or later is required", details: nil))
        }
    }

    // Остановка сканирования
    @objc func stopScan(result: @escaping FlutterResult) {
        if #available(iOS 13.4, *) {
            arView?.session.pause()
            arView?.removeFromSuperview()
            result("Scanning stopped")
        } else {
            result(FlutterError(code: "IOS_TOO_LOW", message: "iOS 13.4 or later is required", details: nil))
        }
    }

    // Экспорт модели в формате .obj
    @objc func exportModel(result: @escaping FlutterResult) {
        if #available(iOS 13.4, *) {
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
                let mdlMesh = MDLMesh(anchor: anchor, device: device)
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
        } else {
            result(FlutterError(code: "IOS_TOO_LOW", message: "iOS 13.4 or later is required", details: nil))
        }
    }
    
    // Отображение ранее сохранённой модели в AR
    @objc func viewModelInAR(result: @escaping FlutterResult) {
        if #available(iOS 13.0, *) {
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
        } else {
            result(FlutterError(code: "IOS_TOO_LOW", message: "iOS 13.0 or later is required for AR view", details: nil))
        }
    }
    
    // Получение последнего экспортированного .obj файла
    private func getLastExportedModelURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        let objFiles = files.filter { $0.pathExtension.lowercased() == "obj" }
        return objFiles.sorted(by: { $0.path > $1.path }).first
    }
}

// Реализация ARSessionDelegate для сбора LiDAR-сеток
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
