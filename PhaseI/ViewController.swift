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
                //noBlue = makingBlue(pixels: viewImage!.pixelData()!, width: (1242*4), height: 1656)
                //noBlue = imageFromRGBA32Bitmap(pixels: viewImage!.pixelData()!, width: (1242*4), height: 1656)
                
                
                if noBlue != nil {
                    print("Blue image should show")
                    self.camPreview.image = noBlue
                    
//                    let previewImageView = UIImageView(image: noBlue)
//
//                    view.addSubview(previewImageView)
//                    previewImageView.frame = camPreview.frame
//
//                                DispatchQueue.main.async { [weak self] in
//                                    self?.camPreview.image = self!.noBlue }
                    } else {
                    print("There is no Blue image")
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
        
        noBlue = processByPixel(in: viewImage!)
        
            DispatchQueue.main.async { [weak self] in
                self?.camPreview.image = self?.noBlue
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
        print ("Pixel Data: \(pixelData.prefix(12))")
        
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
//        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * 4)
//            )
//            else { return nil }
//
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
//            shouldInterpolate: false,
//            intent: .defaultIntent
//            )
//            else { return nil }
//
//        print ("Blue has been made")
//
//        noBlue = UIImage(cgImage: cgim)
//        return noBlue
//    }
//
//}

//extension ViewController {
//    func makingBlue(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
//        //let dataSize = width * height * 4
//        //var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
//        let context = CGContext(data: nil,
//                                width: width,
//                                height: height,
//                                bitsPerComponent: 8,
//                                bytesPerRow: 4 * width,
//                                space: CGColorSpaceCreateDeviceRGB(),
//                                bitmapInfo: bitmapInfo.rawValue)
//
//        let blueImage = context!.makeImage()
//
//        if blueImage != nil {
//            print("Blue image made: \(pixels.prefix(12))")
//        }
//        return UIImage(cgImage: blueImage!)
//    }
//}

extension ViewController {
    func processByPixel(in image: CGImage?) -> UIImage? {
        
        guard let inputCGImage = image else { print("unable to get cgImage"); return nil }
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("Cannot create context!"); return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else { print("Cannot get context data!"); return nil }
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
//        for row in 0 ..< Int(height) {
//            for column in 0 ..< Int(width) {
//                let offset = row * width + column
//                /*
//                 * Here I'm looking for color : RGBA32(red: 231, green: 239, blue: 247, alpha: 255)
//                 * and I will convert pixels color that in range of above color to transparent
//                 * so comparetion can done like this (pixelColorRedComp >= ourColorRedComp - 1 && pixelColorRedComp <= ourColorRedComp + 1 && green && blue)
//                 */
//
////                if pixelBuffer[offset].redComponent >=  230 && pixelBuffer[offset].redComponent <=  232 &&
////                    pixelBuffer[offset].greenComponent >=  238 && pixelBuffer[offset].greenComponent <=  240 &&
////                    pixelBuffer[offset].blueComponent >= 246 && pixelBuffer[offset].blueComponent <= 248 &&
////                    pixelBuffer[offset].alphaComponent == 255 {
////                    print (pixelBuffer[offset].redComponent, pixelBuffer[offset].greenComponent, pixelBuffer[offset].blueComponent,pixelBuffer[offset].alphaComponent)
////                }
        // }
                for row in 0 ..< Int(height) {
                    for column in 0 ..< Int(width) {
                        let offset = row * width + column
                        if pixelBuffer[offset].blueComponent != 255 {
                            pixelBuffer[offset] = .blue
                        }
                    }
                }
        
        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage)

        return outputImage
    }
    
    struct RGBA32: Equatable {
        private var color: UInt32
        
        var redComponent: UInt8 {
            return UInt8((color >> 24) & 255)
        }
        
        var greenComponent: UInt8 {
            return UInt8((color >> 16) & 255)
        }
        
        var blueComponent: UInt8 {
            return UInt8((color >> 8) & 255)
        }
        
        var alphaComponent: UInt8 {
            return UInt8((color >> 0) & 255)
        }
        
        init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
            let red   = UInt32(red)
            let green = UInt32(green)
            let blue  = UInt32(blue)
            let alpha = UInt32(alpha)
            color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
        }
        
        static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
        static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
        static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
        static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
        static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
        static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
        static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
        static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)
        
        static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        
        static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
            return lhs.color == rhs.color
        }
    }
}
