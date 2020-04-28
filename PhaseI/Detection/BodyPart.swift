//
//  BodyPart.swift
//  PhaseI
//
//  Created by Lara Riparip on 22.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import Foundation

open class BodyPart {
    
    var uidx: String
    var partIdx: Int
    var x: CGFloat
    var y: CGFloat
    var score: Double
    var name: String
    
    init(_ uidx: String,_ partIdx: Int,_ x: CGFloat,_ y: CGFloat,_ score: Double){
        self.uidx = uidx
        self.partIdx = partIdx
        self.x = x
        self.y = y
        self.score = score
        self.name = String(format: "BodyPart:%d-(%.2f, %.2f) score=%.2f" , self.partIdx, self.x, self.y, self.score)
    }
    
}
