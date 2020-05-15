//
//  ViewController.swift
//  PhaseI
//
//  Created by Lara Riparip on 21.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var jointViews = UIImageView() // skeletal rendering view
    var timer = Timer()
    let queue = DispatchQueue(label: "videoQueue")
    var coor = [Double](repeating: Double.nan, count: (17)) // check if array is empty
    var poseChecker = Array(repeating: "", count: 5) // check if pose was detected 5 times sequentially
    
    //MARK: - Class Names
    let classNames = ["bridge", "chair", "plank", "standing", "tree",
                      "triangle", "warrior1", "warrior2", "warrior3" ]
    let classNames_cnn = ["plank", "tree", "warrior1", "warrior2", "chair",
                          "bridge", "warrior3", "triangle", "standing"]
    
    //MARK: - Functions
    
    //MARK: Label for Pose Classification
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .darkGray
        label.font = UIFont(name: "selima", size: 42)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: Timer for Pipeline Measurements
    var startTime = CFAbsoluteTime()
    func measure <T> (_ timedFunction: @autoclosure () -> T) -> (result: T, duration: String) {
            let startTime = CFAbsoluteTimeGetCurrent()
            let result = timedFunction()
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            return (result, "Elapsed time is \(timeElapsed) seconds.")
        }
    
    //MARK: Speech Correction
    var previousJoint = String()
    let synth = AVSpeechSynthesizer()
    func speak(_ phrase: String) {
        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.postUtteranceDelay = 1
        utterance.rate = 0.4
        if self.synth.isSpeaking == false {
            self.synth.speak(utterance)
        }
    }
    
    //MARK: - Capture Session
    func cameraSetup(){
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        captureSession.sessionPreset = .vga640x480
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        view.backgroundColor = UIColor(patternImage: UIImage(named: "peachLines.png")!)
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(dataOutput)
        
    }
    
    // MARK: - Setups
    
    fileprivate func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -118).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        identifierLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
        self.identifierLabel.text = "Waiting for Pose"
    }
    
    fileprivate func setupJointView(){
        self.view.addSubview(jointViews)
        jointViews.frame = CGRect(x: -60 , y: 171, width: 551, height: 551)
        jointViews.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    }
    
    // MARK: - Skeletal Rendering
    func drawLine(_ mm: Array<Double>) {
        DispatchQueue.main.async {
            self.jointViews.subviews.forEach({ $0.removeFromSuperview() })
        }
        // var startTime = CFAbsoluteTimeGetCurrent()
        var (keypoint, pos, testing) = drawingBody(mm)
        coor = testing
        
        let opencv = OpenCVWrapper()
        let renderedImage = opencv.renderKeyPoint(CGRect(x: -60 , y: 171, width: 368, height: 368),
                                                              keypoint: &keypoint,
                                                              keypoint_size: Int32(keypoint.count),
                                                              pos: &pos)
        DispatchQueue.main.async {
            self.jointViews.image = renderedImage
            self.view.addSubview(self.jointViews)
        }
            
        // let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        // print("Elapsed time is for rendering is \(timeElapsed) seconds.")
    }

    // MARK: - Postprocessing for XGBoost
    func visionRequestDidComplete_xgboost(request: VNRequest, error: Error?) {
        // xgbclassifier_openpose_angles_5 = cmu model angles relative to parent (update: 16/01/2020)
        
        let model = xgbclassifier_openpose_angles_5()
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation], let heatmaps = observations.first?.featureValue.multiArrayValue {
            // take the output MLMultiArray() and convert to Array()
            let length = heatmaps.count
            let doublePtr =  heatmaps.dataPointer.bindMemory(to: Double.self, capacity: length)
            let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
            let mm = Array(doubleBuffer)
            // draw skeleton onto screen
            drawLine(mm)
            
            // let timedResult = measure(drawLine(mm))
            // print(timedResult.duration)

            //MARK: - XGBoost Classification Model
            // input relative joint angles for pose classification (17 joints)
            guard let output = try? model.prediction(f0: coor[0],   f1: coor[1],   f2: coor[2],    f3: coor[3],
                                                     f4: coor[4],   f5: coor[5],   f6: coor[6],    f7: coor[7],
                                                     f8: coor[8],   f9: coor[9],   f10: coor[10],  f11: coor[11],
                                                     f12: coor[12], f13: coor[13], f14: coor[14],  f15: coor[15],
                                                     f16: coor[16])
            else { fatalError("Unexpected runtime error.") }
            
            // print out classified pose
            let pose = classNames[Int(output.target)]
            print()
            print("=====", pose, "=====")
            print("angles:", coor)
            

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Elapsed time for XGBoost is \(timeElapsed) seconds.")
            
            // check if classified pose is constant for 5 images for a verbal correction
            poseChecker.append(pose)
            if poseChecker.capacity > 5 {
                poseChecker.removeFirst()
            }
            print("poseChecker:", poseChecker)
            let allTheSame = poseChecker.allSatisfy({ $0 == pose })
            if allTheSame == true {
                verbalCorrection(pose:pose)
            }
            
            DispatchQueue.main.async {
                self.identifierLabel.text = "\(pose)"
            }
        } else {
            print("vision observation request failed")
        }
    } // End of visionRequestxgboost
    
// MARK: - Verbal Correction
    func verbalCorrection(pose:String) {
        // var startTime = CFAbsoluteTimeGetCurrent()
        for number in 0...8 {
            if pose == classNames[number] {
                var dict = [Int:Double]()
                for i in 1...12 {
                    let present = coor[i]
                    let past = (correctPose[number])[i]
                    let threshold = Double(15)
                    if present - past > threshold {
                        dict.updateValue(present - past, forKey: i)}
                    else if past - present > threshold {
                        dict.updateValue(present - past, forKey: i)}
                }
                if dict.isEmpty {
                    speak("Your \(classNames[number]) is in perfect form.")
                } else {
                    for i in 0...16 {
                        var largest_angle = dict.values.max()!

                        if largest_angle < (dict.values.min()! / -1.0) {
                            largest_angle = (dict.values.min()!)}

                        if dict[i] == largest_angle {
                            if largest_angle.sign == .minus {
                                if previousJoint != (verbalNeg[number])[i] {
                                    speak(previousJoint)}
                                previousJoint = (verbalNeg[number])[i]
                                print(previousJoint)
                            } else if largest_angle.sign == .plus {
                                if previousJoint != (verbalPos[number])[i] {
                                    speak(previousJoint)}
                                previousJoint = (verbalPos[number])[i]
                                print(previousJoint)
                            }
                        } else { continue }
                    }
                }
                print(dict)
            }
        }
            
// MARK: - Only WARRIOR 2 Correction
        
//        if pose == classNames[7]{
//            var dict = [Int:Double]()
//            for i in 1...12 {
//                let present = coor[i]
//                let past = correctWarrior2[i]
//                let threshold = Double(15)
//                if present - past > threshold {
//                    dict.updateValue(present - past, forKey: i)}
//                else if past - present > threshold {
//                    dict.updateValue(present - past, forKey: i)}
//            }
//            if dict.isEmpty{
//                speak("Your \(classNames[7]) is in perfect form.")}
//            else {
//                for i in 0...16 {
//                    var largest_angle = dict.values.max()!
//
//                    if largest_angle < (dict.values.min()! / -1.0) {
//                        largest_angle = (dict.values.min()!)}
//
//                    if dict[i] == largest_angle {
//                        if largest_angle.sign == .minus {
//                            if previousJoint != verbalNegWarrior2[i] {
//                                speak(previousJoint)}
//                            previousJoint = verbalNegWarrior2[i]
//                            print(previousJoint)
//                        } else if largest_angle.sign == .plus {
//                            if previousJoint != verbalWarrior2[i] {
//                                speak(previousJoint)}
//                            previousJoint = verbalWarrior2[i]
//                            print(previousJoint)
//                        }
//                        
//                    } else { continue }
//                }
//            }
//            print(dict)
////                let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
////                print("Elapsed time for Verbal Correction is \(timeElapsed) seconds.")
//        }
//            } else {
//            for i in 0...classNames.count {
//                if pose == classNames[i]{
//                    speak([(wait: 0.0, phrase: "You are now in \(i)")])}
//                }
//            }
    } // End of Verbal func
    
// MARK: - Pose Estimator Model
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        startTime = CFAbsoluteTimeGetCurrent()
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Load Pose Estimator Model and feed image through
        guard let poseEstimator = try? VNCoreMLModel(for: cmu().model) else { return }
        let poseEstimatorRequest = VNCoreMLRequest(model: poseEstimator, completionHandler: visionRequestDidComplete_xgboost)
        poseEstimatorRequest.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([poseEstimatorRequest])
    
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraSetup()
        setupJointView()
        setupIdentifierConfidenceLabel()
    }
    
} // End of ViewController
