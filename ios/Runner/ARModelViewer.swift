import UIKit
import RealityKit
import ARKit
import SceneKit

class ARModelViewer: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    let arView = ARView(frame: view.bounds)
    view.addSubview(arView)

    let config = ARWorldTrackingConfiguration()
    config.planeDetection = [.horizontal, .vertical]
    arView.session.run(config)

    let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("scan.obj")
    
    let modelEntity = try! ModelEntity.loadModel(contentsOf: fileURL)
    let anchor = AnchorEntity(plane: .any)
    anchor.addChild(modelEntity)
    arView.scene.anchors.append(anchor)
  }
}
