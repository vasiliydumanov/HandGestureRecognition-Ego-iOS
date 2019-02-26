//
//  RecognitionViewController.swift
//  HandGestureDetection-Ego
//
//  Created by Vasiliy Dumanov on 2/12/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit
import AVFoundation

typealias Net = GestureNetNoGarbage

class RecognitionViewController: UIViewController {
    private var _gestureNet: Net!
    private var _inputImageSize: CGSize!
    
    private var _session: AVCaptureSession!
    private var _previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var _framesQueue: DispatchQueue = {
        return DispatchQueue(label: "frames_queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    }()
    private var _pasteRect: CGRect!
    private var _classOverlay: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        createGestureNet()
        checkPermissions()
        setupSession()
        setupPreviewAndBeginCapturing()
        setupClassLabelOverlay()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _previewLayer.frame = view.bounds
    }
    
    private func createGestureNet() {
        _gestureNet = Net()
        guard let imageConstraint = _gestureNet.model.modelDescription.inputDescriptionsByName["image"]?.imageConstraint else {
            fatalError("Cannot find image input with name \"image\"")
        }
        _inputImageSize = CGSize(width: imageConstraint.pixelsWide, height: imageConstraint.pixelsHigh)
    }

    private func checkPermissions() {
    }
    
    private func setupSession() {
        _session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video) else {
            fatalError("No default device for \"video\" mode")
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            fatalError("Unable to create input for a given device.")
        }
        guard _session.canAddInput(input) else {
            fatalError("Unable to add given input to the session.")
        }
        _session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: _framesQueue)
        guard _session.canAddOutput(output) else {
            fatalError("Unable to add given output to the session.")
        }
        _session.addOutput(output)
    }
    
    private func setupPreviewAndBeginCapturing() {
        _previewLayer = AVCaptureVideoPreviewLayer(session: _session)
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .landscapeRight
        view.layer.addSublayer(_previewLayer)
        _session.startRunning()
    }
    
    private func setupClassLabelOverlay() {
        _classOverlay = UILabel()
        _classOverlay.translatesAutoresizingMaskIntoConstraints = false
        _classOverlay.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        _classOverlay.layer.cornerRadius = 16
        _classOverlay.clipsToBounds = true
        _classOverlay.textColor = UIColor.darkGray
        _classOverlay.font = UIFont.boldSystemFont(ofSize: 26)
        _classOverlay.textAlignment = .center
        _classOverlay.isHidden = true
        view.addSubview(_classOverlay)
        _classOverlay.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
        _classOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        _classOverlay.widthAnchor.constraint(equalToConstant: 200).isActive = true
        _classOverlay.heightAnchor.constraint(equalToConstant: 100).isActive = true
    }
    
    private var _lastClass: String = "garbage"
    private var _sameClassCounter: UInt = 0
    private let kSameClassCounterTriggerValue: UInt = 5
    private func updateUIForNew(classProbs: [String: Double]) {
        let classLabel = classProbs
            .filter { k, v in v > 0.8 }
            .max { lhs, rhs in lhs.value > rhs.value }?.key ?? "garbage"
        
        if classLabel == _lastClass {
            if _sameClassCounter != kSameClassCounterTriggerValue {
                _sameClassCounter += 1
            }
        } else {
            _sameClassCounter = 0
        }
        if _sameClassCounter == kSameClassCounterTriggerValue {
            if classLabel == "garbage" {
                _classOverlay.isHidden = true
            } else {
                _classOverlay.text = classLabel
                _classOverlay.isHidden = false
            }
        }
        _lastClass = classLabel
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }

}

extension RecognitionViewController : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let resizedBuffer = performResizeKeepingAspectRatio(for: sourceBuffer)
        guard let pred = try? _gestureNet.prediction(image: resizedBuffer) else {
            print("Prediction failed.")
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateUIForNew(classProbs: pred.classProbabilities)
        }
    }
    
    private func calculatePasteRectIfNeeded(for sourceBuffer: CVPixelBuffer) {
        guard _pasteRect == nil else { return }
        let sourceWidth = CGFloat(CVPixelBufferGetWidth(sourceBuffer))
        let sourceHeight = CGFloat(CVPixelBufferGetHeight(sourceBuffer))
        let sourceRatio = sourceWidth / sourceHeight
        let targetRatio = _inputImageSize.width / _inputImageSize.height
        let scale: CGFloat
        if targetRatio > sourceRatio {
            scale = _inputImageSize.height / sourceHeight
        } else {
            scale = _inputImageSize.width / sourceWidth
        }
        let newSize = CGSize(width: sourceWidth * scale, height: sourceHeight * scale)
        _pasteRect = CGRect(x: (_inputImageSize.width - newSize.width) / 2,
                            y: (_inputImageSize.height - newSize.height) / 2,
                            width: newSize.width,
                            height: newSize.height)
    }
    
    private func performResizeKeepingAspectRatio(for sourceBuffer: CVPixelBuffer) -> CVPixelBuffer {
        let sourceWidth = CGFloat(CVPixelBufferGetWidth(sourceBuffer))
        let sourceHeight = CGFloat(CVPixelBufferGetHeight(sourceBuffer))
        let sourceRatio = sourceWidth / sourceHeight
        let targetRatio = _inputImageSize.width / _inputImageSize.height
        let scale: CGFloat
        if targetRatio > sourceRatio {
            scale = _inputImageSize.height / sourceHeight
        } else {
            scale = _inputImageSize.width / sourceWidth
        }
        let newSize = CGSize(width: round(sourceWidth * scale), height: round(sourceHeight * scale))
        let offset = CGPoint(x: (_inputImageSize.width - newSize.width) / 2,
                             y: (_inputImageSize.height - newSize.height) / 2)
        
        let sourceImg = CIImage(cvImageBuffer: sourceBuffer)
        let resizedImg = sourceImg
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: offset.x, y: offset.y))
        
        guard let targetBuffer = createPixelBuffer(width: Int(_inputImageSize.width),
                                                   height: Int(_inputImageSize.height),
                                                   pixelFormat: kCVPixelFormatType_24BGR)
        else {
            fatalError("Unable to create buffer")
        }
        let ciContext = CIContext()
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        ciContext.render(resizedImg,
                         to: targetBuffer,
                         bounds: CGRect(origin: .zero, size: _inputImageSize),
                         colorSpace: colorSpace)
        CVPixelBufferUnlockBaseAddress(targetBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return targetBuffer
    }
}
