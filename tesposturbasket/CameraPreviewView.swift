//
//  CameraPreviewView.swift
//  tesposturbasket
//
//  Created by Muhamad Alif Anwar on 26/05/25.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let viewModel: PoseDetectionViewModel
    @Binding var isRecording: Bool  // ← Tambahkan ini
    var onImageSaved: ((UIImage) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupCaptureSession(for: view, viewModel: viewModel)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.isRecording = isRecording
        if isRecording {
            context.coordinator.reset() // ⬅️ ini yang penting
        }
    }


    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(viewModel: viewModel)
        coordinator.onImageSaved = onImageSaved // ✅ Hubungkan closure
        return coordinator
    }


    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let captureSession = AVCaptureSession()
        private let viewModel: PoseDetectionViewModel
        private var lastPixelBuffer: CVPixelBuffer?
        var onImageSaved: ((UIImage) -> Void)?



        var isRecording: Bool = false
        private var hasSavedImage = false

        init(viewModel: PoseDetectionViewModel) {
            self.viewModel = viewModel
        }

        
        func setupCaptureSession(for previewView: PreviewView, viewModel: PoseDetectionViewModel) {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else { return }

            captureSession.beginConfiguration()
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            if captureSession.canAddOutput(videoOutput) {
                captureSession.addOutput(videoOutput)
            }

            previewView.videoPreviewLayer.session = captureSession
            previewView.videoPreviewLayer.videoGravity = .resizeAspectFill
            captureSession.commitConfiguration()

            // ✅ Jalankan startRunning di background
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }


        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard isRecording else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // Simpan buffer terbaru
            lastPixelBuffer = pixelBuffer

            DispatchQueue.main.async {
                self.viewModel.processFrame(pixelBuffer: pixelBuffer)
            }

            if viewModel.ballStatus == "Bola ada di tangan" && !hasSavedImage {
                saveImage(from: pixelBuffer)
                hasSavedImage = true
            }
        }


        private func saveImage(from pixelBuffer: CVPixelBuffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .leftMirrored)

            DispatchQueue.main.async {
                self.viewModel.savedBallImages.append(uiImage) // ✅ tambahkan ke array
                self.onImageSaved?(uiImage)
            }

            hasSavedImage = true
        }

        func reset() {
            hasSavedImage = false
        }

        
        
        
        @objc private func saveCurrentFrame() {
            guard let pixelBuffer = lastPixelBuffer, !hasSavedImage else { return }
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                DispatchQueue.main.async {
                    self.viewModel.savedBallImages.append(uiImage)
 
                }
                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                print("📸 Gambar disimpan dari frame dengan bola di tangan")
                hasSavedImage = true
            }
        }

    }
}
