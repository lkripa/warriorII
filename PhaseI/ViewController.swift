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
import AVKit
import Vision
import VideoToolbox
import CoreML


class ViewController: UIViewController {
    
    @IBOutlet weak var camPreview: UIImageView!
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var activeInput: AVCaptureDeviceInput!
    var viewImage: CGImage?
    var modifiedImage: UIImage?
    
    let model = MobileOpenPose()
    let ImageWidth = 368//224
    let ImageHeight = 368 //224
    
    let dataOutputQueue = DispatchQueue(label: "video data queue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .workItem)
    
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    fileprivate func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        identifierLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    @objc func handleTap(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            let touchLocation: CGPoint = sender.location(in: sender.view)
            print (touchLocation)
            print(camPreview.getPixelColorAtPoint(point: touchLocation, sourceView: camPreview))
            
            if viewImage != nil{
                print ("UIImage processed")
                viewImage!.pixelData()
                runCoreML(modifiedImage!)
            } else {
                print("UIImage is empty")
            }
        }
    }
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }
    
    func measure <T> (_ f: @autoclosure () -> T) -> (result: T, duration: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = f()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result, "Elapsed time is \(timeElapsed) seconds.")
    }
    
    lazy var classificationRequest: [VNRequest] = {
        do {
            let model = try VNCoreMLModel(for: self.model.model)
            let classificationRequest = VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
            return [ classificationRequest ]
        } catch {
            fatalError("Can't load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        if setupSession() {
          captureSession.startRunning()
        }
        
        let tap:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.handleTap(sender:)))
        tap.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tap)
        
        setupIdentifierConfidenceLabel()
        
        print("\(OpenCVWrapper.openCVVersionString())")
    }
}

// MARK: - Camera Setup
extension ViewController {
    func setupSession() -> Bool {
        // setup Camera
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
        // 2 setup output
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
            
            // 4 set minimum frame duration to be equal to the supported frame rate of the depth data
            if let frameDuration = camera.activeDepthDataFormat?
                .videoSupportedFrameRateRanges.first?.minFrameDuration {
                camera.activeVideoMinFrameDuration = frameDuration
            }
            
            // 5 unlock configuration
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

// MARK: - Camera Output
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer!)
        
        let previewImage: CIImage
        previewImage = image
        
        viewImage = convertCIImageToCGImage(inputImage: previewImage)
        modifiedImage = processByPixel(in: viewImage!)
        
        // MARK: - Properties of Image Input for model
        
//        let request = VNCoreMLRequest(model: model) { (finishedReq, err) in
//
//            guard let results = finishedReq.results as? [VNClassificationObservation] else { return }
//
//            guard let firstObservation = results.first else { return }
//
//            print(firstObservation.identifier, firstObservation.confidence)
//
//            DispatchQueue.main.async {
//                self.identifierLabel.text = "\(firstObservation.identifier) \(firstObservation.confidence * 100)"
//            }
//        }
        
//        let modifiedpixelBuffer = modifiedImage!.pixelBuffer(width: ImageWidth, height: ImageHeight)
//        runCoreML(modifiedpixelBuffer!)
        //try? VNImageRequestHandler(cvPixelBuffer: modifiedpixelBuffer!, options: [:]).perform([request])
        
            DispatchQueue.main.async { [weak self] in
                self?.camPreview.image = self?.modifiedImage
                }
        }
    }

extension ViewController {
    
    func handleClassification(request: VNRequest, error: Error?) {
        
        guard let observations = request.results as? [VNCoreMLFeatureValueObservation] else { fatalError() }
        let mlarray = observations[0].featureValue.multiArrayValue!
        let length = mlarray.count
        let doublePtr =  mlarray.dataPointer.bindMemory(to: Double.self, capacity: length)
        let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
        let mm = Array(doubleBuffer)
        // Draw new lines
        drawLine(mm)
    }
    
//    func runCoreML(_ pixelBuffer: CVPixelBuffer) {
//        let model = MobileOpenPose()
//        let startTime = CFAbsoluteTimeGetCurrent()
//        if let prediction = try? model.prediction(image: pixelBuffer) {
//
//                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
//                print("coreml elapsed for \(timeElapsed) seconds")
//
//                let predictionOutput = prediction.net_output
//                let length = predictionOutput.count
//                print(predictionOutput)
//
//        }
//    }
    
    func runCoreML(_ image: UIImage) {
        camPreview.image = image
        
        //let img = image.resize(to: CGSize(width: ImageWidth,height: ImageHeight)).cgImage!
        let modifiedpixelBuffer = image.pixelBuffer(width: ImageWidth, height: ImageHeight)
        let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: modifiedpixelBuffer!, options: [:])
        do {
            try classifierRequestHandler.perform(self.classificationRequest)
        } catch {
            print(error)
        }
        
       
    }
    
    func drawLine(_ mm: Array<Double>){
        
        let com = PoseEstimator(ImageWidth,ImageHeight)
        
        let res = measure(com.estimate(mm))
        let humans = res.result;
        print("estimate \(res.duration)")
        
        var keypoint = [Int32]()
        var pos = [CGPoint]()
        for human in humans {
            var centers = [Int: CGPoint]()
            for i in 0...CocoPart.Background.rawValue {
                if human.bodyParts.keys.firstIndex(of: i) == nil {
                    continue
                }
                let bodyPart = human.bodyParts[i]!
                centers[i] = CGPoint(x: bodyPart.x, y: bodyPart.y)
                //                centers[i] = CGPoint(x: Int(bodyPart.x * CGFloat(imageW) + 0.5), y: Int(bodyPart.y * CGFloat(imageH) + 0.5))
            }
            
            for (pairOrder, (pair1,pair2)) in CocoPairsRender.enumerated() {
                
                if human.bodyParts.keys.firstIndex(of: pair1) == nil || human.bodyParts.keys.firstIndex(of: pair2) == nil {
                    continue
                }
                if centers.index(forKey: pair1) != nil && centers.index(forKey: pair2) != nil{
                    keypoint.append(Int32(pairOrder))
                    pos.append(centers[pair1]!)
                    pos.append(centers[pair2]!)
                    //                    addLine(fromPoint: centers[pair1]!, toPoint: centers[pair2]!, color: CocoColors[pairOrder])
                }
            }
        }
        let opencv = OpenCVWrapper()
        let layer = CALayer()
        let uiImage = opencv.renderKeyPoint(camPreview.bounds, keypoint: &keypoint, keypoint_size: Int32(keypoint.count), pos: &pos)
        
        layer.frame = camPreview.bounds
        layer.contents = uiImage.cgImage
        layer.opacity = 0.6
        layer.masksToBounds = true
        self.view.layer.addSublayer(layer)
        
    }
    
    func addLine(fromPoint start: CGPoint, toPoint end:CGPoint, color: UIColor) {
        let line = CAShapeLayer()
        let linePath = UIBezierPath()
        linePath.move(to: start)
        linePath.addLine(to: end)
        line.path = linePath.cgPath
        line.strokeColor = color.cgColor
        line.lineWidth = 3
        line.lineJoin = CAShapeLayerLineJoin.round
        self.view.layer.addSublayer(line)
    }
}

// MARK: - Tap function to retrieve pixel information at a certain point
extension UIImageView {
    func getPixelColorAtPoint(point: CGPoint, sourceView: UIImageView) -> UIColor {
        let pixel = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: pixel,
                                width: 1,
                                height: 1,
                                bitsPerComponent: 8,
                                bytesPerRow: 4,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
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

// MARK: - Function to output pixel data
extension CGImage {
    func pixelData() { //}-> [UInt8]? {
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
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))

        for i in stride(from: pixelData.index(after: 1), to: pixelData.endIndex, by: 4){
            pixelData[i] = 255 // the 255 replaces index 2 which is blue
        }
        print ("Width: \(self.width), Height: \(self.height)")
        print ("Pixel Data: \(pixelData.prefix(12))")

        //return (pixelData)
    }
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}

// MARK: - Function to input camera CGImage, modify, and output UIImage
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
        
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: bitmapInfo)
            else {
            print("Cannot create context!"); return nil
        }
        
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else { print("Cannot get context data!"); return nil }
        
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
                for row in 0 ..< Int(height/2) {
                    for column in 0 ..< Int(width/2) {
                        let offset = row * width + column
                        if pixelBuffer[offset].blueComponent != 255 {
                            //pixelBuffer[offset] = .blue
                            pixelBuffer[offset].color = pixelBuffer[offset].color | (255 << 8)
                        }
                    }
                }
        
        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage)

        return outputImage
    }
}
    
