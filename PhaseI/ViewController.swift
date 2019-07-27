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
    
    static var instance: ViewController?
    weak var delegate: RectangleDetectorDelegate?
    let rectangleDetector = RectangleDetector()
    
    let model = MobileOpenPose()
    let ImageWidth = 368
    let ImageHeight = 368
    
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
            //let touchLocation: CGPoint = sender.location(in: sender.view)
            //print ("Touch Location: \(touchLocation)")
            //print(camPreview.getPixelColorAtPoint(point: touchLocation, sourceView: camPreview))
            
            if viewImage != nil{
                //print ("UIImage processed")
                //viewImage!.pixelData()
                //runCoreML(modifiedImage!)
                
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
    
    func resetImage() {
        // Delete Beizer paths of previous image
        DispatchQueue.global().async {
            self.camPreview.layer.sublayers = []
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
        
        setupIdentifierConfidenceLabel()
        rectangleDetector.delegate = self
        
    }
}

class RectangleDetector {
    
    let model = MobileOpenPose()
    let ImageWidth = 368
    let ImageHeight = 368
    
    private var currentCameraImage: CVPixelBuffer!
    
    private var updateTimer: Timer?
    
    /// The number of times per second to check for rectangles.
    /// - Tag: UpdateInterval
    private var updateInterval: TimeInterval = 0.1
    
    /// - Tag: IsBusy
    private var isBusy = false
    
    /// - Tag: InitializeVisionTimer
    init() {
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            if let capturedImage = ViewController.instance?.camPreview.image {
                self?.search(capturedImage)
            }
        }
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
    
    /// Search for rectangles in the camera's pixel buffer,
    ///  if a search is not already running.
    /// - Tag: SerializeVision
    private func search(_ image: UIImage) {
        guard !isBusy else { return }
        isBusy = true
        let img = image.resize(to: CGSize(width: ImageWidth,height: ImageHeight))
        let modifiedpixelBuffer = img.pixelBuffer(width: ImageWidth, height: ImageHeight)
        
        // Note that the pixel buffer's orientation doesn't change even when the device rotates.
        let handler = VNImageRequestHandler(cvPixelBuffer: modifiedpixelBuffer!, options: [:])
        do {
            try handler.perform(classificationRequest)
            } catch {
                print(error)
            }
    
        
        DispatchQueue.global().async {
            do {
                try handler.perform([classificationRequest])
            } catch {
                print("Error: Rectangle detection failed - vision request failed.")
                self.isBusy = false
            }
        }
    }
}

extension ViewController: RectangleDetectorDelegate {
    /// Called when the app recognized a rectangular shape in the user's envirnment.
    /// - Tag: NewAlteredImage
    func rectangleFound(rectangleContent: CIImage) {
        DispatchQueue.main.async {
            
            // Ignore detected rectangles if the app is currently tracking an image.
            guard self.modifiedImage == nil else {
                return
            }
            
            // Try tracking the image that lies within the rectangle the app just detected.
            guard let newAlteredImage = AlteredImage(rectangleContent) else { return }
            newAlteredImage.delegate = self
            self.alteredImage = newAlteredImage
            
            // Start the session with the newly recognized image.
            self.runImageTrackingSession(with: [newAlteredImage.referenceImage])
        }
    }
}

protocol RectangleDetectorDelegate: class {
    func rectangleFound(rectangleContent: CIImage)
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
//
//    func runCoreML(_ image: UIImage) {
//        //camPreview.image = image
//
//        let img = image.resize(to: CGSize(width: ImageWidth,height: ImageHeight))
//        let modifiedpixelBuffer = img.pixelBuffer(width: ImageWidth, height: ImageHeight)
//
//        let image = CIImage(cvPixelBuffer: modifiedpixelBuffer!)
//        let previewImage: CIImage = image
//
//        let testingPixels = convertCIImageToCGImage(inputImage: previewImage)
//        testingPixels?.pixelData()
//
//        let classifierRequestHandler = VNImageRequestHandler(cvPixelBuffer: modifiedpixelBuffer!, options: [:])
//        do {
//            try classifierRequestHandler.perform(self.classificationRequest)
//        } catch {
//            print(error)
//        }
//    }

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
}

// MARK: - Camera Output
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer!)
        let previewImage: CIImage = image
        
        viewImage = convertCIImageToCGImage(inputImage: previewImage)
        modifiedImage = processByPixel(in: viewImage!)
        //runCoreML(modifiedImage!)
       
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
        
        resetImage()
        drawLine(mm)
    }
    
    func drawLine(_ mm: Array<Double>){
        let com = PoseEstimator(ImageWidth,ImageHeight)
        
        let res = measure(com.estimate(mm))
        let humans = res.result
        print("Estimate drawing measurement \(res.duration)")
        
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
        //let uiImage = opencv.renderKeyPoint(camPreview.bounds, keypoint: &keypoint, keypoint_size: Int32(keypoint.count), pos: &pos)
        
        layer.frame = CGRect(x: 10, y: 172, width: 440, height: 495)
        layer.backgroundColor = UIColor.red.cgColor
        //layer.contents = uiImage.cgImage
        layer.opacity = 0.6
        layer.masksToBounds = true
        
        //self.view.layer.addSublayer(layer)
        let renderedImage = opencv.renderKeyPoint(layer.frame,
                                                            keypoint: &keypoint,
                                                            keypoint_size: Int32(keypoint.count),
                                                            pos: &pos)
        layer.contents = renderedImage.cgImage
        camPreview.layer.addSublayer(layer)
        
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

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        print ("Resized - Width: \(resizedImage.size.width * resizedImage.scale), Height: \(resizedImage.size.height * resizedImage.scale)" )
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

                for row in width ..< Int(height) {
                    for column in 0 ..< Int(width) {
                        let offset = row * width + column
//                        if pixelBuffer[offset].alphaComponent == 255 {
//                            pixelBuffer[offset].color = pixelBuffer[offset].color | (0 << 0)
//                        }
                            if pixelBuffer[offset] != .transparent {
                                pixelBuffer[offset] = .transparent
                            }
                    }
                }

        let outputCGImage = context.makeImage()!
        let outputImage = UIImage(cgImage: outputCGImage)
        

        return outputImage
    }
}
    
