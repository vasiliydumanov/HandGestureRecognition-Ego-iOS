//
//  ViewController.swift
//  HandGestureDetection-Ego
//
//  Created by Vasiliy Dumanov on 2/8/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private func imgToBuffer(_ img: UIImage) -> CVPixelBuffer {
        let fullRect = CGRect(x: 0, y: 0, width: 640, height: 480)
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(fullRect.width), Int(fullRect.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else { fatalError() }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(fullRect.width), height: Int(fullRect.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: fullRect.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        let newImgSize: CGSize
        if img.size.width / img.size.height > fullRect.width / fullRect.height {
            newImgSize = CGSize(
                width: fullRect.width,
                height: (fullRect.width / img.size.width) * img.size.height)
        } else {
            newImgSize = CGSize(
                width: (fullRect.height / img.size.height) * img.size.width,
                height: fullRect.height)
        }
        
        UIGraphicsPushContext(context!)
        UIColor.black.setFill()
        context?.fill(fullRect)
        img.draw(in: CGRect(
            x: (fullRect.width - newImgSize.width) / 2,
            y: (fullRect.height - newImgSize.height) / 2,
            width: newImgSize.width,
            height: newImgSize.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer!
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let model = GestureNetNoGarbage()
        
        let classNames = ["one", "two", "three", "five", "good", "bad"]
        let buffers = classNames.map { name -> CVPixelBuffer in
            let img = UIImage(contentsOfFile: Bundle.main.path(forResource: name, ofType: "jpg")!)!
            return self.imgToBuffer(img)
        }
        
        for (className, buffer) in zip(classNames, buffers) {
            let pred = try! model.prediction(image: buffer)
            let probs = pred.classProbabilities
            print("Ground truth: \(className), Probs: \(probs)")
        }
    
    }


}

