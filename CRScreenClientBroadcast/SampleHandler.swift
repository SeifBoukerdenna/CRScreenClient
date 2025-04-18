import ReplayKit
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
  // replace 192.168.1.42 with your Mac’s LAN IP and port
  let uploadURL = URL(string: "http://192.168.2.150:8080/upload")!
  let session = URLSession(configuration: .default)

  override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
    // nothing special to do here
  }

  override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                    with sampleBufferType: RPSampleBufferType) {
    // only handle video frames
    guard sampleBufferType == .video,
          let jpeg = jpegData(from: sampleBuffer) else {
      return
    }

    var req = URLRequest(url: uploadURL)
    req.httpMethod = "POST"
    req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
    session.uploadTask(with: req, from: jpeg).resume()
  }

  override func broadcastFinished() {
    // clean up if needed
  }

  private func jpegData(from buffer: CMSampleBuffer) -> Data? {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else { return nil }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    let context = CIContext()
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    let uiImage = UIImage(cgImage: cgImage)
    return uiImage.jpegData(compressionQuality: 0.7)
  }
}
