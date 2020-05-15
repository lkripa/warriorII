//
//  Connection.swift
//  PhaseI
//
//  Created by Lara Riparip on 22.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import Foundation

public struct Connection {
    var score: Double // confidence score of two coordinates for pair
    var partIdx1: Int // enum joint 1 number
    var partIdx2: Int // enum joint 2 number
    var idx1: Int // part 1 identification number of this image
    var idx2: Int // part 2 identification number of this image
    var coord1: (CGFloat, CGFloat) //x-, y-coordinates of joint 1
    var coord2: (CGFloat, CGFloat) //x-, y-coordinates of joint 2
    var score1: Double // confidence score 1 of part identification
    var score2: Double // confidences score 2 of part identification
    
    init(score: Double,
         partIdx1: Int,partIdx2: Int,
         idx1: Int,idx2: Int,
         coord1: (CGFloat,CGFloat),coord2:(CGFloat,CGFloat),
         score1: Double,score2: Double) {
        self.score = score
        self.partIdx1 = partIdx1
        self.partIdx2 = partIdx2
        self.idx1 = idx1
        self.idx2 = idx2
        self.coord1 = coord1
        self.coord2 = coord2
        self.score1 = score1
        self.score2 = score2
        
      
    }
}
