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
    
    var jointViews = UIImageView()
    var timer = Timer()
    let queue = DispatchQueue(label: "videoQueue")
    var coor = [Double](repeating: Double.nan, count: (17))
    var poseChecker = Array(repeating: "", count: 5)
    
    //MARK: - Class Names
    let classNames = ["bridge", "chair", "plank", "standing", "tree",
                      "triangle", "warrior1", "warrior2", "warrior3" ]
    let classNames_cnn = ["plank", "tree", "warrior1", "warrior2", "chair",
                          "bridge", "warrior3", "triangle", "standing"]
    
    //MARK: - Functions
    
    //MARK: Label for Pose Classification
    let identifierLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = .white
        label.textAlignment = .center
        label.textColor = .black
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
        previewLayer.frame = view.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(dataOutput)
        
    }
    
    // MARK: - Setups
    
    fileprivate func setupIdentifierConfidenceLabel() {
        view.addSubview(identifierLabel)
        identifierLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32).isActive = true
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
          let poseEst = PoseEstimator(368,368)
          let timedResult = measure(poseEst.estimate(mm))
          let humans = timedResult.result
          var keypoint = [Int32]()
          var pos = [CGPoint]()
          let primary = [0,2,5,8,11, 14,15,16,17]

        
          for human in humans {
            print("humans: \(humans.count)")
            var centers = [Int: CGPoint]()
            var testing = [Double](repeating: Double.nan, count: (17))
            for i in 0...CocoPart.Background.rawValue {
                if human.bodyParts.keys.firstIndex(of: i) == nil {
                    continue
                }
                let bodyPart = human.bodyParts[i]!
                if human.bodyParts[1] != nil {
                    let neckJoint = human.bodyParts[1]!
                    if i != 1 {
                        if primary.contains(i) {
                            let xx = bodyPart.x - neckJoint.x
                            let yy = bodyPart.y - neckJoint.y
                            let cos_angle = xx / (sqrt( (pow(xx, 2) + pow(yy, 2) )))
                            let angle = (acos(cos_angle) * 180 / CGFloat.pi)
                            if i != 0 {
                               testing[i-1] = Double(angle)

                            } else{
                               testing[0] = Double(angle)
                            }
                        } else {
                            if human.bodyParts[i] != nil {
                                let first_joint = human.bodyParts[i]!
                                let second_joint = human.bodyParts[i-1]!
                                let xx = first_joint.x - second_joint.x
                                let yy = first_joint.y - second_joint.y
                                let cos_angle = xx / (sqrt( (pow(xx, 2) + pow(yy, 2) )))
                                let angle = (acos(cos_angle) * 180 / CGFloat.pi)
                                testing[i-1] = Double(angle)
                            }
                        }
                    }
                }
                centers[i] = CGPoint(x: bodyPart.x, y: bodyPart.y)
          }
            
            let weirdness = testing.allSatisfy({$0.isNaN})
            if weirdness {
                print ("It is all nan values")
            } else {
                 coor = testing
            }
            
              for (pairOrder, (pair1,pair2)) in CocoPairsRender.enumerated() {

                  if human.bodyParts.keys.firstIndex(of: pair1) == nil || human.bodyParts.keys.firstIndex(of: pair2) == nil {
                      continue
                  }
                  if centers.index(forKey: pair1) != nil && centers.index(forKey: pair2) != nil{
                      keypoint.append(Int32(pairOrder))
                      pos.append(centers[pair1]!)
                      pos.append(centers[pair2]!)
                  }
              }

            let opencv = OpenCVWrapper()
            let renderedImage = opencv.renderKeyPoint(CGRect(x: -60 , y: 171, width: 368, height: 368),
                                                              keypoint: &keypoint,
                                                              keypoint_size: Int32(keypoint.count),
                                                              pos: &pos)
            DispatchQueue.main.async {
                self.jointViews.image = renderedImage
                self.view.addSubview(self.jointViews)
            }
            
        }
        // let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        // print("Elapsed time is for rendering is \(timeElapsed) seconds.")
    }

    // MARK: - Postprocessing for XGBoost
    func visionRequestDidComplete_xgboost(request: VNRequest, error: Error?) {
        // xgbclassifier # 5 = cmu angles relative (update: 16/01/2020)
        
        let model = xgbclassifier_openpose_angles_5()
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {
//            let pafmaps = observations[0].featureValue.multiArrayValue,
//            let heatmaps = observations[1].featureValue.multiArrayValue {

            let length = heatmaps.count
            let doublePtr =  heatmaps.dataPointer.bindMemory(to: Double.self, capacity: length)
            let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
            let mm = Array(doubleBuffer)
            print("heatmaps \(mm.count)")
            
            drawLine(mm)
            // let timedResult = measure(drawLine(mm))
            // print(timedResult.duration)

 //MARK: - XGBoost Classification Model
            guard let output = try? model.prediction(f0: coor[0],
                                                     f1: coor[1],
                                                     f2: coor[2],
                                                     f3: coor[3],
                                                     f4: coor[4],
                                                     f5: coor[5],
                                                     f6: coor[6],
                                                     f7: coor[7],
                                                     f8: coor[8],
                                                     f9: coor[9],
                                                     f10: coor[10],
                                                     f11: coor[11],
                                                     f12: coor[12],
                                                     f13: coor[13],
                                                     f14: coor[14],
                                                     f15: coor[15],
                                                     f16: coor[16])
                else {
                fatalError("Unexpected runtime error.")
                }
//            guard let output = try? model2.prediction(conv2d_1_input__0: heatmaps)
//            else {
//            fatalError("Unexpected runtime error.")
//            }

                let pose = classNames[Int(output.target)]
                print(coor)
                print(pose)

            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Elapsed time for XGBoost is \(timeElapsed) seconds.")
            
            poseChecker.append(pose)
            if poseChecker.capacity > 5 {
                poseChecker.removeFirst()
            }
            print(poseChecker)
            let allTheSame = poseChecker.allSatisfy({ $0 == pose })
            if allTheSame == true {
                verbalCorrection(pose:pose)
            }
            
            DispatchQueue.main.async {
                self.identifierLabel.text = "\(pose)"
            }
        } else {
            print("observation request failed")
        }
    } // End of visionRequestxgboost
    
    // MARK: - Postprocessing for CNN
    func visionRequestDidComplete_cnn(request: VNRequest, error: Error?) {
        // let model2 = mapClassifier_46x46_dim1()
        let model2 = mapClassifier_46x46_dim1_97()
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let heatmaps = observations.first?.featureValue.multiArrayValue {

            let length = heatmaps.count
            let doublePtr =  heatmaps.dataPointer.bindMemory(to: Double.self, capacity: length)
            let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
            let mm = Array(doubleBuffer)

//            drawLine(mm)

            let heatRows = 46
            let heatColumns = 46

            let singleImage = heatRows*heatColumns
//            let separateLen = 19*heatRows*heatColumns
//            let separateLen2 = 38*heatRows*heatColumns
//
//            let heatmapData = Array<Double>(mm[0..<separateLen])
//            let pafX = Array<Double>(mm[separateLen..<separateLen2])
//            let pafY = Array<Double>(mm[separateLen2..<mm.count])
            
            let keypoint_number = heatmaps.shape[0].intValue // 57
//            let heatmap_w = heatmaps.shape[1].intValue // 46
//            let heatmap_h = heatmaps.shape[2].intValue // 46
            var summedArray = Array(repeating: 0.0, count: 2116)

            for k in 0..<(keypoint_number) {
                let oneImage = Array<Double>(mm[k*singleImage..<(k+1)*singleImage])
//                print (oneImage.count)
                summedArray = zip(summedArray, oneImage).map(+)
            }
//           summedArray = summedArray + summedArray + summedArray
//            let opencv = OpenCVWrapper()
//            opencv.matrixMin(
//                &heatmapData,
//                data_size: Int32(heatmapData.count),
//                data_rows: 19,
//                heat_rows: Int32(heatRows)
//            )
//            opencv.matrixMin(
//                &pafX,
//                data_size: Int32(pafX.count),
//                data_rows: 19,
//                heat_rows: Int32(heatRows)
//            )
//
//            opencv.matrixMin(
//                &pafY,
//                data_size: Int32(pafY.count),
//                data_rows: 19,
//                heat_rows: Int32(heatRows)
//            )
            
            // ------- LEFT OFF HERE ----------
            // ------- LEFT OFF HERE ----------
            // ------- LEFT OFF HERE ----------
            // ------- LEFT OFF HERE ----------
            
//            let keypoint_number = heatmaps.shape[0].intValue // 57
//            let heatmap_w = heatmaps.shape[1].intValue // 46
//            let heatmap_h = heatmaps.shape[2].intValue // 46
//
//            var convertedHeatmap: Array<Array<Double>> = Array(repeating: Array(repeating: 0.0, count: heatmap_h), count: heatmap_w)
//
//            for k in 0..<(keypoint_number/3) {
//                for i in 0..<heatmap_w {
//                    for j in 0..<heatmap_h {
//                        let index = k*(heatmap_w*heatmap_h) + i*(heatmap_h) + j
//                        let confidence = heatmaps[index].doubleValue
//                        convertedHeatmap[j][i] += confidence
//                    }
//                }
//            }
//        print(convertedHeatmap_array[0][0].count,convertedHeatmap_array[0][1].count,convertedHeatmap_array[0][2].count)
//            let doublePtr_cnn = UnsafeMutablePointer<Double>.allocate(capacity: 2116)
//            doublePtr_cnn.initialize(from: &summedArray, count: 2116)
//            guard var finalSummedArray = try? MLMultiArray(dataPointer: doublePtr_cnn, shape: [46,46], dataType: MLMultiArrayDataType.double, strides: [46, 46, 1]) else {return}
            guard let finalSummedArray = try? MLMultiArray(shape: [1,46,46], dataType: MLMultiArrayDataType.double) else {return}
            for (index, element) in summedArray.enumerated() {
                finalSummedArray[index] = NSNumber(floatLiteral: element)
            }
//            finalSummedArray = MLMultiArray(convertedHeatmap)
//             for i in 0..<heatmap_w {
//                 for j in 0..<heatmap_h {
//                    let index = i*(heatmap_h) + j
//                    finalSummedArray = NSNumber(floatLiteral: summedArray(index))
//            print("print finalSummedArray:\((finalSummedArray))") }}
//
//           let timedResult = measure(drawLine(mm))
//           print(timedResult.duration)
//
     //MARK: - CNN Classification Model
        guard let output = try? model2.prediction(conv2d_1_input__0: finalSummedArray)
            else {
                fatalError("Unexpected runtime error.") }

            let prediction = output.dense_2__Softmax__0
            let doublePtr_cnn =  prediction.dataPointer.bindMemory(to: Double.self, capacity: 9)
            let doubleBuffer_cnn = UnsafeBufferPointer(start: doublePtr_cnn, count: 9)
            let prediction_cnn = Array(doubleBuffer_cnn)
            let indexPose = prediction_cnn.firstIndex(of: prediction_cnn.max()!)!
            let pose = classNames_cnn[indexPose]
            print(pose)
        
        verbalCorrection(pose:pose)
        DispatchQueue.main.async {
            self.identifierLabel.text = "\(pose)" }
    } else { print ("observation request failed") }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Elapsed time for CNN is \(timeElapsed) seconds.")
    } // End of CNN func

// MARK: - Verbal Correction
    func verbalCorrection(pose:String) {
//            var startTime = CFAbsoluteTimeGetCurrent()
        
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
            }}
            
// MARK: - For WARRIOR 2 Correction
        
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
