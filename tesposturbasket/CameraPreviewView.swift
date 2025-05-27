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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.setupCaptureSession(for: view, viewModel: viewModel)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private let captureSession = AVCaptureSession()
        private let viewModel: PoseDetectionViewModel

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
            captureSession.startRunning()
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            viewModel.processFrame(pixelBuffer: pixelBuffer)
        }
    }
}

