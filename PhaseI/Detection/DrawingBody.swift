//
//  DrawingBody.swift
//  PhaseI
//
//  Created by Lara Riparip on 29.04.20.
//  Copyright © 2020 Lara Riparip. All rights reserved.
//

import Foundation

func calculateAngles(_ xx: CGFloat, _ yy: CGFloat) -> CGFloat {
    let cos_angle = xx / (sqrt( (pow(xx, 2) + pow(yy, 2) )))
    let angle = (acos(cos_angle) * 180 / CGFloat.pi)
    return angle
}

func drawingBody(_ mm: Array<Double>) -> ([Int32], [CGPoint], [Double]) {
    
    var keypoint = [Int32]()
    var pos = [CGPoint]()
    var coor = [Double](repeating: Double.nan, count: (17)) // array later fed into pose classifier
    let primary = [0,2,5,8,11, 14,15,16,17] // primary joints
    let poseEst = PoseEstimator(368,368) // image pixel buffer size
    
    // image array is fed into the pose estimator
    let humans = poseEst.estimate(mm)
   

    for human in humans {
        print("humans: \(humans.count)")
        var centers = [Int: CGPoint]()
        var testing = [Double](repeating: Double.nan, count: (17))
        
        // checking for each of the body parts, locate and calculate joint angles
        for i in 0...CocoPart.Background.rawValue {
            if human.bodyParts.keys.firstIndex(of: i) == nil {
                continue
            }
            let bodyPart = human.bodyParts[i]!
            // neckJoint is detected in human
            if human.bodyParts[1] != nil {
                // bodyParts set relative to neckJoint [1]
                let neckJoint = human.bodyParts[1]!
                if i != 1 {
                    // primary joints are joints closest to the center of the body
                    if primary.contains(i) {
                        let xx = bodyPart.x - neckJoint.x
                        let yy = bodyPart.y - neckJoint.y
                        // calculate angle from parent joint to child joint
                        let angle = calculateAngles(xx, yy)
                        // place the angles in the proper order in bodyParts
                        if i != 0 {
                           testing[i-1] = Double(angle)
                        } else {
                           testing[0] = Double(angle)
                        }
                        
                    } else {
                        // bodyParts set relative to the joint closest to the center of the body
                        // secondary joint angles are calculated
                        if human.bodyParts[i] != nil {
                            let first_joint = human.bodyParts[i]!
                            let second_joint = human.bodyParts[i-1]!
                            let xx = first_joint.x - second_joint.x
                            let yy = first_joint.y - second_joint.y
                            let angle = calculateAngles(xx, yy)
                            testing[i-1] = Double(angle)
                        }
                    }
                }
            }
            centers[i] = CGPoint(x: bodyPart.x, y: bodyPart.y)
        }
        
        // array is checked if all are NaN values
        let weirdness = testing.allSatisfy({$0.isNaN})
        if weirdness {
            print ("It is all nan values")
        } else {
            coor = testing
        }
        
        // for each body part pair, the parts are paired together to form a human.
        // keypoints and positions are then calculated
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
    } // end of humans loop
    
    return (keypoint, pos, coor)
}
