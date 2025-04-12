import Foundation
import ARKit
import SceneKit
import UIKit
import RealityKit
import ModelIO

class LidarScanner: NSObject, ARSessionDelegate {
    
    static let shared = LidarScanner()
    
    private let session = ARSession()
    private var scanStarted = false
    private var capturedMeshAnchors: [ARMeshAnchor] = []
    
    private override init() {
        super.init()
        session.delegate = self
    }
    
    func startScan() {
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        config.frameSemantics = .sceneDepth
        config.sceneReconstruction = .mesh
        config.planeDetection = [.horizontal, .vertical]
        
        capturedMeshAnchors.removeAll()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        scanStarted = true
    }
    
    func stopScan() {
        session.pause()
        scanStarted = false
    }
    
    func exportModel(completion: @escaping (URL?) -> Void) {
        guard !capturedMeshAnchors.isEmpty else {
            completion(nil)
            return
        }
        
        let allocator = MTKMeshBufferAllocator(device: MTLCreateSystemDefaultDevice()!)
        let asset = MDLAsset(bufferAllocator: allocator)
        
        for anchor in capturedMeshAnchors {
            let geometry = anchor.geometry
            let vertices = geometry.vertices
            let vertexCount = vertices.count
            let vertexBuffer = allocator.newBuffer(MemoryLayout<vector_float3>.stride * vertexCount, type: .vertex)
            
            let vertexPointer = vertexBuffer.map().bytes.assumingMemoryBound(to: vector_float3.self)
            for i in 0..<vertexCount {
                vertexPointer[i] = geometry.vertex(at: UInt32(i))
            }
            
            let indexCount = geometry.faces.count * 3
            let indexBuffer = allocator.newBuffer(MemoryLayout<UInt32>.stride * indexCount, type: .index)
            let indexPointer = indexBuffer.map().bytes.assumingMemoryBound(to: UInt32.self)
            var indexOffset = 0
            
            for faceIndex in 0..<geometry.faces.count {
                let face = geometry.face(at: UInt32(faceIndex))
                if face.count == 3 {
                    for i in 0..<3 {
                        indexPointer[indexOffset] = face.index(at: i)
                        indexOffset += 1
                    }
                }
            }
            
            let mdlMesh = MDLMesh(vertexBuffer: vertexBuffer,
                                  vertexCount: vertexCount,
                                  descriptor: MDLVertexDescriptor(),
                                  submeshes: [MDLSubmesh(indexBuffer: indexBuffer,
                                                         indexCount: indexCount,
                                                         indexType: .uInt32,
                                                         geometryType: .triangles,
                                                         material: nil)])
            asset.add(mdlMesh)
        }
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("scan.obj")
        do {
            try asset.export(to: fileURL)
            completion(fileURL)
        } catch {
            print("Failed to export model: \(error)")
            completion(nil)
        }
    }
    
    // Delegate method
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let mesh = anchor as? ARMeshAnchor {
                capturedMeshAnchors.append(mesh)
            }
        }
    }
}
