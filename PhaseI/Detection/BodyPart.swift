//
//  BodyPart.swift
//  PhaseI
//
//  Created by Lara Riparip on 22.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import Foundation

// class for joint body parts
open class BodyPart {
    
    var uidx: String // number of uniquely identified connection (from one image)
    var partIdx: Int // enum joint number; part index(eg. 0 for nose)
    var x: CGFloat // x-coordinate in percentage
    var y: CGFloat // y-coordinate in percentage
    var score: Double // confidence score of part identification
    var name: String // return name of body part and information
    
    init(_ uidx: String,_ partIdx: Int,_ x: CGFloat,_ y: CGFloat,_ score: Double){
        self.uidx = uidx
        self.partIdx = partIdx
        self.x = x
        self.y = y
        self.score = score
        self.name = String(format: "BodyPart:%d-(%.2f, %.2f) score=%.2f" , self.partIdx, self.x, self.y, self.score)
    }
    
}
