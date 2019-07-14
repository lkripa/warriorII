//
//  ViewController.swift
//  PhaseI
//
//  Created by Lara Riparip on 09.07.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import UIKit
import AVFoundation
import CoreGraphics

class ViewController: UIViewController {
    
    @IBOutlet weak var camPreview: UIImageView!
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    var viewImage: CGImage?
    var noBlue: UIImage?
    
    let dataOutputQueue = DispatchQueue(label: "video data queue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .workItem)
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let touchLocation: CGPoint = sender.location(in: sender.view)
            print (touchLocation)
            print(camPreview.getPixelColorAtPoint(point: touchLocation, sourceView: camPreview))
            
            if viewImage != nil{
                print ("There is a viewImage")
                noBlue = imageFromRGBA32Bitmap(pixels: viewImage!.pixelData()!, width: (1242*4), height: 1656)

                if noBlue != nil {
                    print("Blue will be shown")
                    let previewImageView = UIImageView(image: noBlue)
                    view.addSubview(previewImageView)

                    //            DispatchQueue.main.async { [weak self] in
                    //                self?.camPreview.image = self!.noBlue
                    //}
                }
                else {
                    print("There is no Blue")
                }

            } else {
                print("UIImage is empty")
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    
        if setupSession() {
          captureSession.startRunning()
        }
        
        let tap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(sender:)))
        tap.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tap)
    }
}

extension ViewController {
    func setupSession() -> Bool {
        //captureSession.sessionPreset = AVCaptureSession.Preset.high
        
        // Setup Camera
        guard let camera = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) else { fatalError("No Depth Camera")}
        
        captureSession.sessionPreset = .photo
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                activeInput = input //this is not in the depth map
            }
        } catch {
            print("Error setting device video input: \(error)")
            return false
        }
        // 2.setup output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: dataOutputQueue)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        let videoConnection = output.connection(with: .video)
        videoConnection?.videoOrientation = .portrait
        
        // 3 lock AVCaptureDevice
        do {
            try camera.lockForConfiguration()
            
            // 4 Set minimum frame duration to be equal to teh supported frame rate of the depth data
            if let frameDuration = camera.activeDepthDataFormat?
                .videoSupportedFrameRateRanges.first?.minFrameDuration {
                camera.activeVideoMinFrameDuration = frameDuration
            }
            
            // 5 Unlock Configuration
            camera.unlockForConfiguration()
        } catch {
            fatalError(error.localizedDescription)
        }
        return true
    }
        
    
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = AVCaptureVideoOrientation.portrait
        case .landscapeRight:
            orientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            orientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            orientation = AVCaptureVideoOrientation.landscapeRight
        }
        return orientation
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer!)
        
        let previewImage: CIImage
        previewImage = image
        
        
        func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
                return cgImage
            }
            return nil
        }
        viewImage = convertCIImageToCGImage(inputImage: previewImage)
        
        let displayImage = UIImage(ciImage: previewImage)
            DispatchQueue.main.async { [weak self] in
            self?.camPreview.image = displayImage
                }
        }
    }

extension UIImageView {
    func getPixelColorAtPoint(point: CGPoint, sourceView: UIImageView) -> UIColor {
        let pixel = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        
        context!.translateBy(x: -point.x, y: -point.y)
        
        
        sourceView.layer.render(in: context!)
        let color: UIColor = UIColor(red: CGFloat(pixel[0])/255.0,
                                     green: CGFloat(pixel[1])/255.0,
                                     blue: CGFloat(pixel[2])/255.0,
                                     alpha: CGFloat(pixel[3])/255.0)
        
        pixel.deallocate()
    return color
}
}

extension CGImage {
    func pixelData() -> [UInt8]? {
        let dataSize = self.width * self.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(self.width),
                                height: Int(self.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(self.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        //guard let cgImage = self.cgImage else { return nil }
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        
        for i in stride(from: pixelData.index(after: 1), to: pixelData.endIndex, by: 4){
            pixelData[i] = 255 // the 255 replaces index 2 which is blue
        }
        print ("Width: \(self.width), Height: \(self.height)")
        print ((pixelData.prefix(12)))
        
        return (pixelData)
    }
}

//extension ViewController {
//    func imageFromRGBA32Bitmap(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
//        guard width > 0 && height > 0 else { return nil }
//        guard pixels.count == width * height else { return nil }
//
//        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
//        let bitsPerComponent = 8
//        let bitsPerPixel = 32
//
//        var data = pixels // Copy to mutable []
//        guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
//                                                            length: data.count * 4)
//            )
//            else { return nil }
//
//        guard let cgim = CGImage(
//            width: width,
//            height: height,
//            bitsPerComponent: bitsPerComponent,
//            bitsPerPixel: bitsPerPixel,
//            bytesPerRow: width * 4,
//            space: rgbColorSpace,
//            bitmapInfo: bitmapInfo,
//            provider: providerRef,
//            decode: nil,
//            shouldInterpolate: true,
//            intent: .defaultIntent
//            )
//            else { return nil }
//
//        print ("Blue has been made")
//        return UIImage(cgImage: cgim)
//
//    }
//
//}


extension ViewController {
    
    
    func imageFromRGBA32Bitmap(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
        guard width > 0 && height > 0 else { return nil }
        guard pixels.count == width * height else { return nil }
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        
        var data = pixels // Copy to mutable []
        guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
                                                            length: data.count * 4)
            )
            else { return nil }
        
        guard let cgim = CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: width * 4,
            space: rgbColorSpace,
            bitmapInfo: bitmapInfo,
            provider: providerRef,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
            )
            else { return nil }
        
        print ("Blue has been made")
        return UIImage(cgImage: cgim)
        
    }
    
}
