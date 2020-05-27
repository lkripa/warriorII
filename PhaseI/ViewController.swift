//
//  ViewController.swift
//  PhaseI
//
//  Created by Lara Riparip on 21.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

// TODO: Check Verbal output of left/right/stance smaller
// TODO: The end check is still broken

import UIKit
import AVKit
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var jointViews = UIImageView() // skeletal rendering view
    var correctJointView = UIImageView() // correct skeleton in top right corner
    var imageView = UIImageView() // intro background view
    var timer = Timer()
    let queue = DispatchQueue(label: "videoQueue")
    var coor = [Double](repeating: Double.nan, count: (17)) // check if array is empty
    var poseChecker = Array(repeating: "", count: 3) // check if pose was detected 3 times sequentially
    var selectedPose = Int()
    let captureSession = AVCaptureSession() // set up camera capture
    var previewLayer = AVCaptureVideoPreviewLayer() // camera image layer
    let button = UIButton(frame: CGRect(x: 300, y: 200, width: 300, height: 70)) // button for home screen
    var restartButton = UIButton(frame: CGRect(x: 20, y: 805, width: 70, height: 70))
    var isPoseCorrect = false //command for ending verbal correction

    //MARK: - Class Names
    let classNames     = ["bridge", "chair", "plank", "standing", "tree",
                          "triangle", "warrior1", "warrior2", "warrior3" ]
    let classNames_cnn = ["plank", "tree", "warrior1", "warrior2", "chair",
                          "bridge", "warrior3", "triangle", "standing"]
    
    //MARK: - Functions
    
    //MARK: Label for Pose Classification
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .darkGray
        label.numberOfLines = 2
        label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        label.font = UIFont(name: "selima", size: 72)
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
    func cameraSetup() {
        captureSession.sessionPreset = .photo
        captureSession.sessionPreset = .vga640x480
        
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) // mirror the image if using .front camera
        previewLayer.frame = view.bounds // view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(dataOutput)
    }
    
    // MARK: - Setups
    
    // label on the top of screen view during start
    fileprivate func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 102).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20).isActive = true
        identifierLabel.heightAnchor.constraint(equalToConstant: 200).isActive = true
        
        identifierLabel.text = "Choose your yoga pose"
        identifierLabel.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        identifierLabel.font = UIFont(name: "selima", size: 72)
    }
    
    // label on the bottom of screen view during correction setup
    fileprivate func moveIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40).isActive = true
        identifierLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive = true
        identifierLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        
        identifierLabel.text = "Waiting for Pose"
        identifierLabel.backgroundColor = UIColor.white.withAlphaComponent(0)
        identifierLabel.font = UIFont(name: "selima", size: 52)
    }
    
    // skeletal joint view setup
    fileprivate func setupJointView(){
        self.view.addSubview(jointViews)
        jointViews.frame = CGRect(x: -60 , y: 170, width: 551, height: 551)
    }
    
    // skeletal joint view setup in the top right corner of camera view
    fileprivate func setupCorrectJointView(){
        self.view.addSubview(correctJointView)
        correctJointView.frame = CGRect(x: 280 , y: 135, width: 150, height: 150)
    }
    
    // intro view setup
    fileprivate func setupBackground(){
        self.view.addSubview(imageView)
        self.view.sendSubviewToBack(imageView)
        imageView.image = UIImage(named: "PinkAndPeach.png")
        imageView.frame = view.frame
        imageView.contentMode = UIView.ContentMode.scaleAspectFill
    }
    
    // button view setup
    fileprivate func setupButtonView(){
        self.view.addSubview(button)
        button.layer.cornerRadius = 15.0
        button.layer.borderWidth = 1.0
        button.backgroundColor = UIColor.red.withAlphaComponent(0.4)
        button.setTitle("Warrior II (right)", for: .normal)
        button.titleLabel?.font = UIFont(name: "selima", size: 42)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)

        let verticalCenter: CGFloat = UIScreen.main.bounds.size.height / 2.0
        let horizonalCenter: CGFloat = UIScreen.main.bounds.size.width / 2.0
        button.center = CGPoint(x: horizonalCenter, y: verticalCenter)
    }

    // button for selecting a pose and starting camera session
    @objc func buttonAction(sender: UIButton!){
        print(classNames[7])
        isPoseCorrect = false
        selectedPose = 7
        reset()
        
        //setup camera correction screen
        drawCorrectSkeleton()
        self.button.removeFromSuperview()
        self.identifierLabel.removeFromSuperview()
        captureSession.startRunning()
        moveIdentifierConfidenceLabel()
    }
    
    // app reset for a new pose correction and start correction mode
    func reset(){
        coor = [Double](repeating: Double.nan, count: (17)) // check if array is empty
        poseChecker = Array(repeating: "", count: 3)
        
        self.previewLayer.isHidden = false
        self.jointViews.isHidden = false
        self.correctJointView.isHidden = false
        self.restartButton.isHidden = false
        self.imageView.removeFromSuperview()
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "peachLines.png")!)
    }
    
    // starting screen: camera view is hidden and intro background is setup
    func setupInital(){
        self.previewLayer.isHidden = true
        self.jointViews.isHidden = true
        self.correctJointView.isHidden = true
        self.restartButton.isHidden = true
        self.setupButtonView()
        self.setupBackground()
        self.setupIdentifierConfidenceLabel()
    }
    
//     move to starting screen
    fileprivate func setupRestartButton(){
        self.view.addSubview(restartButton)
        restartButton.setImage(UIImage(named: "RestartButton"), for: .normal)
        restartButton.addTarget(self, action: #selector(restartAction), for: .touchUpInside)
    }
    
    @objc func restartAction(sender: UIButton!){
        // starting screen setup
        self.stopSession()
        isPoseCorrect = true
    }
    
    
    // MARK: - Skeletal Rendering
    func drawLine(_ mm: Array<Double>) {
        DispatchQueue.main.async {
            self.jointViews.subviews.forEach({ $0.removeFromSuperview() })
        }
        // var startTime = CFAbsoluteTimeGetCurrent()
        var (keypoint, pos, testing) = drawingBody(mm)
        coor = testing
        print(keypoint, pos)
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
    
    // MARK: - Skeletal Rendering
    func drawCorrectSkeleton() {
        let opencv = OpenCVWrapper()
        var keypoint = [Int32]()
        var pos = [CGPoint]()
        keypoint = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
        pos = [CGPoint(x: 0.5434782608695652, y: 0.5),
               CGPoint(x: 0.4782608695652174, y: 0.5),
               CGPoint(x: 0.5434782608695652, y: 0.5),
               CGPoint(x: 0.6086956521739131, y: 0.5),
               CGPoint(x: 0.4782608695652174, y: 0.5),
               CGPoint(x: 0.3695652173913043, y: 0.5),
               CGPoint(x: 0.3695652173913043, y: 0.5),
               CGPoint(x: 0.2391304347826087, y: 0.5),
               CGPoint(x: 0.6086956521739131, y: 0.5),
               CGPoint(x: 0.717391304347826, y: 0.5),
               CGPoint(x: 0.717391304347826, y: 0.5),
               CGPoint(x: 0.7826086956521738, y: 0.5),
               CGPoint(x: 0.5434782608695652, y: 0.5),
               CGPoint(x: 0.4782608695652174, y: 0.717391304347826),
               CGPoint(x: 0.4782608695652174, y: 0.717391304347826),
               CGPoint(x: 0.30434782608695654, y: 0.8043478260869565),
               CGPoint(x: 0.30434782608695654, y: 0.8043478260869565),
               CGPoint(x: 0.30434782608695654, y: 0.9782608695652174),
               CGPoint(x: 0.5434782608695652, y: 0.5),
               CGPoint(x: 0.5869565217391304, y: 0.7391304347826086),
               CGPoint(x: 0.5869565217391304, y: 0.7391304347826086),
               CGPoint(x: 0.717391304347826, y: 0.8695652173913043),
               CGPoint(x: 0.717391304347826, y: 0.8695652173913043),
               CGPoint(x: 0.8260869565217391, y: 0.9782608695652174),
               CGPoint(x: 0.5434782608695652, y: 0.5),
               CGPoint(x: 0.5434782608695652, y: 0.43478260869565216),
               CGPoint(x: 0.5434782608695652, y: 0.43478260869565216),
               CGPoint(x: 0.5217391304347826, y: 0.41304347826086957),
               CGPoint(x: 0.5217391304347826, y: 0.41304347826086957),
               CGPoint(x: 0.5, y: 0.41304347826086957),
               CGPoint(x: 0.5434782608695652, y: 0.43478260869565216),
               CGPoint(x: 0.5434782608695652, y: 0.41304347826086957),
               CGPoint(x: 0.5434782608695652, y: 0.41304347826086957),
               CGPoint(x: 0.5869565217391304, y: 0.41304347826086957)
        ]
    
        
        let renderedImage = opencv.renderKeyPoint(CGRect(x: 0 , y: 0, width: 368, height: 368),
                                                 keypoint: &keypoint,
                                                 keypoint_size: Int32(keypoint.count),
                                                 pos: &pos)
        DispatchQueue.main.async {
           self.correctJointView.image = renderedImage
           self.view.addSubview(self.correctJointView)
        }

    }

    // MARK: - Postprocessing for XGBoost
    func visionRequestDidComplete_xgboost(request: VNRequest, error: Error?) {
        // NOTE: xgbclassifier_openpose_angles_5 = cmu model angles relative to parent (update: 16/01/2020)
        
        let model = xgbclassifier_openpose_angles_5()
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
            
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
            var pose = classNames[Int(output.target)]
            if coor.allSatisfy( {$0.isNaN} ) {
                pose = "Waiting for Pose"
            }
            print()
            print("=====", pose, "=====")
            print("angles:", coor)
           
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Elapsed time for XGBoost is \(timeElapsed) seconds.")
            
            // check if classified pose is constant for 3 images for a verbal correction
            poseChecker.append(pose)
            if poseChecker.capacity > 3 {
                poseChecker.removeFirst()
            }
            print("poseChecker:", poseChecker)
            let allTheSame = poseChecker.allSatisfy({ $0 == classNames[selectedPose] })
            if allTheSame == true {
                verbalCorrection(pose:pose)
            }
            
            DispatchQueue.main.async {
                self.identifierLabel.text = "\(pose)"
                if self.isPoseCorrect == true {
                    self.identifierLabel.text = "Choose your yoga pose"
                }
            }
            
        } else {
            print("vision observation request failed")
        }
    } // End of visionRequestxgboost
    
// MARK: - Verbal Correction
    func verbalCorrection(pose:String) {
        // var startTime = CFAbsoluteTimeGetCurrent()
        if isPoseCorrect == false {
            if pose == classNames[selectedPose] {
                var dict = [Int:Double]()
                for i in 1...12 {
                    let present = coor[i]
                    let past = (correctPose[selectedPose])[i]
                    let threshold = Double(15)
                    if present - past > threshold {
                        dict.updateValue(present - past, forKey: i)
                        
                    } else if past - present > threshold {
                        dict.updateValue(present - past, forKey: i)
                    }
                }
                
                // if there are no errors larger than 15 degrees, it is in perfect form
                if dict.isEmpty {
                    // check if talking, and pose is in perfect form and verbal command is spoken for the correction to stop
                    if self.synth.isSpeaking == false {
                        isPoseCorrect = true
                        speak("Your \(classNames[selectedPose]) is in perfect form.")
                        print("Your \(classNames[selectedPose]) is in perfect form.")
                    }
                } else {
                    // find the biggest error in the joint angles and say correction
                    for i in 0...16 {
                        var largest_angle = dict.values.max()!
                        
                        // keep the largest absolute angle difference
                        if largest_angle < abs(dict.values.min()!) {
                            largest_angle = (dict.values.min()!)
                        }

                        // verbal corrections if the correction movement is up or down
                        if dict[i] == largest_angle {
                            if largest_angle.sign == .minus {
                                if previousJoint != (verbalNeg[selectedPose])[i] {
                                    speak(previousJoint)}
                                previousJoint = (verbalNeg[selectedPose])[i]
                                print(previousJoint)
                            } else if largest_angle.sign == .plus {
                                if previousJoint != (verbalPos[selectedPose])[i] {
                                    speak(previousJoint)
                                }
                                previousJoint = (verbalPos[selectedPose])[i]
                                print(previousJoint)
                            }
                        } else { continue }
                    }
                }
                print(dict)
                }
        } else {
            stopSession()
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
//                            if previousJoint != verbalPosWarrior2[i] {
//                                speak(previousJoint)}
//                            previousJoint = verbalPosWarrior2[i]
//                            print(previousJoint)
//                        }
//
//                    } else { continue }
//                }
//            }
//            print(dict)
//                 // let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
//                // print("Elapsed time for Verbal Correction is \(timeElapsed) seconds.")
//        }
    } // End of Verbal func
    
// MARK: - Pose Estimator Model
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        startTime = CFAbsoluteTimeGetCurrent()
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // load Pose Estimator Model and feed image through
        guard let poseEstimator = try? VNCoreMLModel(for: cmu().model) else { return }
        let poseEstimatorRequest = VNCoreMLRequest(model: poseEstimator, completionHandler: visionRequestDidComplete_xgboost)
        poseEstimatorRequest.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right)
        try? handler.perform([poseEstimatorRequest])
    
    }
    
    // stop camera session and reset view to button selection
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.stopRunning()
            }
        }
        
        // starting screen setup
        DispatchQueue.main.async {
            self.identifierLabel.removeFromSuperview()
            self.setupInital()
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        cameraSetup()
        setupJointView()
        setupCorrectJointView()
        setupRestartButton()
        setupInital() // start of app, camera view is hidden
    }
    
} // End of ViewController
