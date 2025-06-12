import Foundation
import Vision
import AVFoundation
import SwiftUI
import CoreGraphics
import CoreML


class PoseDetectionViewModel: NSObject, ObservableObject {
    @Published var feedbackText: String = ""
    @Published var currentPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]? = nil
    @Published var overlayColor: Color = .gray
    @Published var ballStatus: String = "Status bola belum terdeteksi"

    
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
    
    
//    func processFrame(pixelBuffer: CVPixelBuffer) {
//        let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
//            guard let self = self else { return }
//            guard let observations = request.results as? [VNHumanBodyPoseObservation],
//                  let first = observations.first else {
//                DispatchQueue.main.async {
//                    self.feedbackText = "Tidak ada pose terdeteksi"
//                    self.currentPoints = nil
//                    self.overlayColor = .gray
//                }
//                return
//            }
//            
//            do {
//                let jointPoints = try first.recognizedPoints(.all)
//                self.evaluatePose(points: jointPoints)
//            } catch {
//                print("Error evaluating pose: \(error)")
//            }
//        }
//        
//        // === Tambahan: Deteksi Bola Basket ===
//        let config = MLModelConfiguration()
//        guard let basketballModel = try? VNCoreMLModel(for: hasilCheckBall(configuration: config).model) else {
//            print("Failed to load BasketballDetector model")
//            return
//        }
//        
//        let basketballRequest = VNCoreMLRequest(model: basketballModel) { [weak self] request, error in
//            guard let self = self else { return }
//            if let results = request.results as? [VNRecognizedObjectObservation] {
//                var ballDetectedNearHand = false
//                
//                for result in results where result.labels.first?.identifier == "basketball" {
//                    let boundingBox = result.boundingBox
//                    let confidence = result.labels.first?.confidence ?? 0
//                    
//                    // --- Cek apakah bola dekat dengan tangan kanan ---
//                    if let rightWrist = self.currentPoints?[.rightWrist], rightWrist.confidence > 0.5 {
//                        let wristPoint = CGPoint(x: CGFloat(rightWrist.location.x), y: CGFloat(1 - rightWrist.location.y))
//                        let ballRect = boundingBox
//                        
//                        // Bandingkan posisi wrist dengan posisi bola
//                        if ballRect.contains(wristPoint) {
//                            ballDetectedNearHand = true
//                        }
//                    }
//                    
//                    print("Basketball detected at \(boundingBox), confidence: \(confidence)")
//                }
//                
//                DispatchQueue.main.async {
//                    self.ballStatus = ballDetectedNearHand ? "Bola ada di tangan" : "Bola terlepas"
//                }
//            } else {
//                DispatchQueue.main.async {
//                    self.ballStatus = "Bola tidak terdeteksi"
//                }
//            }
//        }
//    }

    
    func processFrame(pixelBuffer: CVPixelBuffer) {
        let poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
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
                print("Error evaluating pose: \(error)")
            }
        }

        // Request harus dijalankan
        do {
            try sequenceHandler.perform([poseRequest], on: pixelBuffer)
        } catch {
            print("Gagal memproses poseRequest: \(error)")
        }

        // Tambahan: Deteksi bola
        let config = MLModelConfiguration()
        guard let basketballModel = try? VNCoreMLModel(for: hasilCheckBall(configuration: config).model) else {
            print("Failed to load BasketballDetector model")
            return
        }
        
        let basketballRequest = VNCoreMLRequest(model: basketballModel) { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNRecognizedObjectObservation] {
                print("Jumlah objek terdeteksi: \(results.count)")
                for result in results {
                    print("Label: \(result.labels.first?.identifier ?? "unknown"), confidence: \(result.labels.first?.confidence ?? 0)")
                    print("Bounding Box: \(result.boundingBox)")
                }
            } else {
                print("Tidak ada hasil deteksi bola.")
            }
        }


        // Jalankan juga request untuk bola
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([basketballRequest])
    }

    
    private func evaluatePose(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) {
        DispatchQueue.main.async {
            self.currentPoints = points
            var feedbacks: [String] = []
            var hasError = false

            func convertPoint(_ point: VNRecognizedPoint) -> CGPoint {
                return CGPoint(x: CGFloat(point.location.x), y: CGFloat(1 - point.location.y))
            }

            // --- Check Elbow (shooting arm, let's say right) ---
            if let rightShoulder = points[.rightShoulder],
               let rightElbow = points[.rightElbow],
               let rightWrist = points[.rightWrist],
               rightShoulder.confidence > 0.5,
               rightElbow.confidence > 0.5,
               rightWrist.confidence > 0.5 {

                let angleElbow = self.angleBetweenPoints(
                    pointA: convertPoint(rightShoulder),
                    pointB: convertPoint(rightElbow),
                    pointC: convertPoint(rightWrist)
                )

                if angleElbow < 90 {
                    feedbacks.append("Siku terlalu sempit")
                    hasError = true
                    self.overlayColor = .red
                } else if angleElbow > 110 {
                    feedbacks.append("Siku terlalu terbuka")
                    hasError = true
                    self.overlayColor = .red
                } else {
                    feedbacks.append("Siku posisi bagus!")
                    self.overlayColor = .green
                }
            } else {
                feedbacks.append("Pose siku tidak jelas")
                hasError = true
            }

            // --- Check Knee (shooting leg, right) ---
            if let rightHip = points[.rightHip],
               let rightKnee = points[.rightKnee],
               let rightAnkle = points[.rightAnkle],
               rightHip.confidence > 0.5,
               rightKnee.confidence > 0.5,
               rightAnkle.confidence > 0.5 {

                let angleKnee = self.angleBetweenPoints(
                    pointA: convertPoint(rightHip),
                    pointB: convertPoint(rightKnee),
                    pointC: convertPoint(rightAnkle)
                )

                if angleKnee < 100 {
                    feedbacks.append("Tekuk lutut sedikit lebih dalam")
                    hasError = true
                } else if angleKnee > 150 {
                    feedbacks.append("Lutut terlalu lurus, kurang lentur")
                    hasError = true
                } else {
                    feedbacks.append("Lutut posisi bagus!")
                }
            } else {
                feedbacks.append("Pose lutut tidak jelas")
                hasError = true
            }

            // --- Check Body Balance ---
            if let rightShoulder = points[.rightShoulder],
               let rightHip = points[.rightHip],
               let rightAnkle = points[.rightAnkle],
               rightShoulder.confidence > 0.5,
               rightHip.confidence > 0.5,
               rightAnkle.confidence > 0.5 {

                let verticalAlignment = abs(convertPoint(rightShoulder).x - convertPoint(rightHip).x) +
                                        abs(convertPoint(rightHip).x - convertPoint(rightAnkle).x)

                if verticalAlignment > 0.1 {
                    feedbacks.append("Tubuh agak miring, perbaiki keseimbangan")
                    hasError = true
                } else {
                    feedbacks.append("Keseimbangan tubuh bagus!")
                }
            } else {
                feedbacks.append("Pose tubuh tidak jelas")
                hasError = true
            }

            // Combine feedback
            self.feedbackText = feedbacks.joined(separator: "\n")

            // Set overlay color
            self.overlayColor = hasError ? .red : .green
        }
    }

}
