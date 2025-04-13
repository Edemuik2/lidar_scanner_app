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

    // Инициализатор, который принимает UIViewController (root view controller)
    @objc init(viewController: UIViewController) {
        self.viewController = viewController
    }

    // Запускает сканирование LiDAR
    @objc func startScan(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            result(FlutterError(code: "UNSUPPORTED_DEVICE", message: "Device does not support LiDAR scanning", details: nil))
            return
        }
        
        // Инициализируем ARView и добавляем его в основное представление
        let arView = ARView(frame: UIScreen.main.bounds)
        self.arView = arView
        viewController?.view.addSubview(arView)
        
        // Настраиваем конфигурацию ARKit
        let config = ARWorldTrackingConfiguration()
        config.sceneReconstruction = .mesh
        config.environmentTexturing = .automatic
        config.planeDetection = [.horizontal, .vertical]
        
        arView.session.delegate = self
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        meshAnchors.removeAll()
        
        result("Scanning started")
    }

    // Останавливает сканирование
    @objc func stopScan(result: @escaping FlutterResult) {
        arView?.session.pause()
        arView?.removeFromSuperview()
        result("Scanning stopped")
    }

    // Экспортирует 3D-модель в формате .obj с использованием SceneKit
    @objc func exportModel(result: @escaping FlutterResult) {
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
        
        // Для каждого якоря создаём MDLMesh и добавляем его в MDLAsset
        for anchor in meshAnchors {
            let mdlMesh = MDLMesh(anchor: anchor, device: device)
            asset.add(mdlMesh)
        }
        
        let fileName = "scan-\(Int(Date().timeIntervalSince1970)).obj"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // Используем SceneKit для экспорта модели
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
    
    // Отображает последнюю экспортированную 3D-модель в AR
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
            
            let arVC = UIViewController()
            arVC.view = arView
            viewController?.present(arVC, animated: true, completion: nil)
            result("Model displayed in AR")
        } catch {
            result(FlutterError(code: "VIEW_FAILED", message: "Failed to load model for AR", details: error.localizedDescription))
        }
    }
    
    // Получает последний экспортированный OBJ-файл из временной директории
    private func getLastExportedModelURL() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return nil
        }
        let objFiles = files.filter { $0.pathExtension.lowercased() == "obj" }
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
