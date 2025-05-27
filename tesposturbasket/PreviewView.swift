//
//  PreviewView.swift
//  tesposturbasket
//
//  Created by Muhamad Alif Anwar on 26/05/25.
//

import UIKit
import AVFoundation

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
