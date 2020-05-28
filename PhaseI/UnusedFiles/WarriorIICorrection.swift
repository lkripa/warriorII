//
//  WarriorIICorrection.swift
//  PhaseI
//
//  Created by Lara Riparip on 28.05.20.
//  Copyright © 2020 Lara Riparip. All rights reserved.
//

import Foundation

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
