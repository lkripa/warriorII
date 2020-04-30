//
//  CNN.swift
//  PhaseI
//
//  Created by Lara Riparip on 29.04.20.
//  Copyright © 2020 Lara Riparip. All rights reserved.
//

import Foundation

// MARK: - Postprocessing for CNN
//    func visionRequestDidComplete_cnn(request: VNRequest, error: Error?) {
//        // let model2 = mapClassifier_46x46_dim1()
//        let model2 = mapClassifier_46x46_dim1_97()
//
//        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
//            let heatmaps = observations.first?.featureValue.multiArrayValue {
//
//            let length = heatmaps.count
//            let doublePtr =  heatmaps.dataPointer.bindMemory(to: Double.self, capacity: length)
//            let doubleBuffer = UnsafeBufferPointer(start: doublePtr, count: length)
//            let mm = Array(doubleBuffer)
//
////            drawLine(mm)
//
//            let heatRows = 46
//            let heatColumns = 46
//
//            let singleImage = heatRows*heatColumns
////            let separateLen = 19*heatRows*heatColumns
////            let separateLen2 = 38*heatRows*heatColumns
////
////            let heatmapData = Array<Double>(mm[0..<separateLen])
////            let pafX = Array<Double>(mm[separateLen..<separateLen2])
////            let pafY = Array<Double>(mm[separateLen2..<mm.count])
//
//            let keypoint_number = heatmaps.shape[0].intValue // 57
////            let heatmap_w = heatmaps.shape[1].intValue // 46
////            let heatmap_h = heatmaps.shape[2].intValue // 46
//            var summedArray = Array(repeating: 0.0, count: 2116)
//
//            for k in 0..<(keypoint_number) {
//                let oneImage = Array<Double>(mm[k*singleImage..<(k+1)*singleImage])
////                print (oneImage.count)
//                summedArray = zip(summedArray, oneImage).map(+)
//            }
////           summedArray = summedArray + summedArray + summedArray
////            let opencv = OpenCVWrapper()
////            opencv.matrixMin(
////                &heatmapData,
////                data_size: Int32(heatmapData.count),
////                data_rows: 19,
////                heat_rows: Int32(heatRows)
////            )
////            opencv.matrixMin(
////                &pafX,
////                data_size: Int32(pafX.count),
////                data_rows: 19,
////                heat_rows: Int32(heatRows)
////            )
////
////            opencv.matrixMin(
////                &pafY,
////                data_size: Int32(pafY.count),
////                data_rows: 19,
////                heat_rows: Int32(heatRows)
////            )
//
//            // ------- LEFT OFF HERE ----------
//            // ------- LEFT OFF HERE ----------
//            // ------- LEFT OFF HERE ----------
//            // ------- LEFT OFF HERE ----------
//
////            let keypoint_number = heatmaps.shape[0].intValue // 57
////            let heatmap_w = heatmaps.shape[1].intValue // 46
////            let heatmap_h = heatmaps.shape[2].intValue // 46
////
////            var convertedHeatmap: Array<Array<Double>> = Array(repeating: Array(repeating: 0.0, count: heatmap_h), count: heatmap_w)
////
////            for k in 0..<(keypoint_number/3) {
////                for i in 0..<heatmap_w {
////                    for j in 0..<heatmap_h {
////                        let index = k*(heatmap_w*heatmap_h) + i*(heatmap_h) + j
////                        let confidence = heatmaps[index].doubleValue
////                        convertedHeatmap[j][i] += confidence
////                    }
////                }
////            }
////        print(convertedHeatmap_array[0][0].count,convertedHeatmap_array[0][1].count,convertedHeatmap_array[0][2].count)
////            let doublePtr_cnn = UnsafeMutablePointer<Double>.allocate(capacity: 2116)
////            doublePtr_cnn.initialize(from: &summedArray, count: 2116)
////            guard var finalSummedArray = try? MLMultiArray(dataPointer: doublePtr_cnn, shape: [46,46], dataType: MLMultiArrayDataType.double, strides: [46, 46, 1]) else {return}
//            guard let finalSummedArray = try? MLMultiArray(shape: [1,46,46], dataType: MLMultiArrayDataType.double) else {return}
//            for (index, element) in summedArray.enumerated() {
//                finalSummedArray[index] = NSNumber(floatLiteral: element)
//            }
////            finalSummedArray = MLMultiArray(convertedHeatmap)
////             for i in 0..<heatmap_w {
////                 for j in 0..<heatmap_h {
////                    let index = i*(heatmap_h) + j
////                    finalSummedArray = NSNumber(floatLiteral: summedArray(index))
////            print("print finalSummedArray:\((finalSummedArray))") }}
////
////           let timedResult = measure(drawLine(mm))
////           print(timedResult.duration)
////
//     //MARK: - CNN Classification Model
//        guard let output = try? model2.prediction(conv2d_1_input__0: finalSummedArray)
//            else {
//                fatalError("Unexpected runtime error.") }
//
//            let prediction = output.dense_2__Softmax__0
//            let doublePtr_cnn =  prediction.dataPointer.bindMemory(to: Double.self, capacity: 9)
//            let doubleBuffer_cnn = UnsafeBufferPointer(start: doublePtr_cnn, count: 9)
//            let prediction_cnn = Array(doubleBuffer_cnn)
//            let indexPose = prediction_cnn.firstIndex(of: prediction_cnn.max()!)!
//            let pose = classNames_cnn[indexPose]
//            print(pose)
//
//        verbalCorrection(pose:pose)
//        DispatchQueue.main.async {
//            self.identifierLabel.text = "\(pose)" }
//    } else { print ("observation request failed") }
//
//        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
//        print("Elapsed time for CNN is \(timeElapsed) seconds.")
//    } // End of CNN func
