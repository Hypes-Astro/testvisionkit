import Foundation
import Vision
import AVFoundation
import SwiftUI
import CoreGraphics

class PoseDetectionViewModel: NSObject, ObservableObject {
    @Published var feedbackText: String = ""
    @Published var currentPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]? = nil
    @Published var overlayColor: Color = .gray
    
    private let sequenceHandler = VNSequenceRequestHandler()
    
    
    func angleBetweenPoints(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint) -> CGFloat {
        let vectorBA = CGVector(dx: pointA.x - pointB.x, dy: pointA.y - pointB.y)
        let vectorBC = CGVector(dx: pointC.x - pointB.x, dy: pointC.y - pointB.y)
        
        let dotProduct = vectorBA.dx * vectorBC.dx + vectorBA.dy * vectorBC.dy
        let magnitudeBA = sqrt(vectorBA.dx * vectorBA.dx + vectorBA.dy * vectorBA.dy)
        let magnitudeBC = sqrt(vectorBC.dx * vectorBC.dx + vectorBC.dy * vectorBC.dy)
        
        guard magnitudeBA > 0, magnitudeBC > 0 else {
            return 0
        }
        
        let cosineAngle = dotProduct / (magnitudeBA * magnitudeBC)
        // Batasi nilai cosine agar tidak melebihi rentang -1...1 karena pembulatan floating-point
        let clampedCosine = min(1, max(-1, cosineAngle))
        
        let angleRadians = acos(clampedCosine)
        let angleDegrees = angleRadians * 180 / .pi
        return angleDegrees
    }
    
    
    func processFrame(pixelBuffer: CVPixelBuffer) {
        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let first = observations.first else {
                DispatchQueue.main.async {
                    self.feedbackText = "Tidak ada pose terdeteksi"
                    self.currentPoints = nil
                    self.overlayColor = .gray
                }
                return
            }
            
            do {
                let jointPoints = try first.recognizedPoints(.all)
                self.evaluatePose(points: jointPoints)
            } catch {
                print("Error: \(error)")
            }
        }
        
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Failed request: \(error)")
        }
    }
    
    private func evaluatePose(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        DispatchQueue.main.async {
            self.currentPoints = points
            
            guard let leftElbow = points[.leftElbow],
                  let leftShoulder = points[.leftShoulder],
                  let leftWrist = points[.leftWrist],
                  leftElbow.confidence > 0.5,
                  leftShoulder.confidence > 0.5,
                  leftWrist.confidence > 0.5 else {
                self.feedbackText = "Pose tidak jelas"
                self.overlayColor = .gray
                return
            }
            
            // Konversi lokasi Vision (0,0 kiri bawah) ke coordinate SwiftUI (0,0 kiri atas) jika perlu
            func convertPoint(_ point: VNRecognizedPoint) -> CGPoint {
                return CGPoint(x: CGFloat(point.location.x), y: CGFloat(1 - point.location.y))
            }
            
            let shoulderPt = convertPoint(leftShoulder)
            let elbowPt = convertPoint(leftElbow)
            let wristPt = convertPoint(leftWrist)
            
            let angle = self.angleBetweenPoints(pointA: shoulderPt, pointB: elbowPt, pointC: wristPt)
            
            // Misal target angle siku antara 70-110 derajat dianggap pose bagus
            if angle < 70 {
                self.feedbackText = "Angkat siku lebih rendah"
                self.overlayColor = .red
            } else if angle > 110 {
                self.feedbackText = "Turunkan siku lebih banyak"
                self.overlayColor = .yellow
            } else {
                self.feedbackText = "Siku posisi bagus!"
                self.overlayColor = .green
            }
        }
    }    
}
