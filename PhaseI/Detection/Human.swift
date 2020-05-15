//  Human.swift
//  PhaseI
//
//  Created by Lara Riparip on 22.11.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import Foundation

open class Human {
    
    var pairs : [Connection] // skeletal connection of two body parts
    var bodyParts : [Int: BodyPart] // enum label of body part
    var uidxList: Set<String> // unique list of idx
    var name = ""
    
    init(_ pairs: [Connection]) {
        
        self.pairs = [Connection]()
        self.bodyParts = [Int: BodyPart]()
        self.uidxList = Set<String>() //set id of both part 1 and part 2 of a connection
        
        // add connection of two joints
        for pair in pairs {
            self.addPair(pair)
        }
        self.name = (self.bodyParts.map{ $0.value.name }).joined(separator:" ")
    }
    
    // uidx is the part id + id number from the image
    func _getUidx(_ partIdx: Int,_ idx: Int) -> String {
        return String(format: "%d-%d", partIdx, idx)
    }
    
    // adds the pair information to the set of uidxList
    func addPair(_ pair: Connection){
        self.pairs.append(pair)
        
        self.bodyParts[pair.partIdx1] = BodyPart(_getUidx(pair.partIdx1, pair.idx1),
                                                 pair.partIdx1,
                                                 pair.coord1.0, pair.coord1.1, pair.score)
        
        self.bodyParts[pair.partIdx2] = BodyPart(_getUidx(pair.partIdx2, pair.idx2),
                                                 pair.partIdx2,
                                                 pair.coord2.0, pair.coord2.1, pair.score)
        
        // determine uidx
        let uidx: [String] = [_getUidx(pair.partIdx1, pair.idx1),_getUidx(pair.partIdx2, pair.idx2)]
        self.uidxList.formUnion(uidx)
    }
    
    // merge pairs
    func merge(_ other: Human){
        for pair in other.pairs {
            self.addPair(pair)
        }
    }
    
    // check if part is connected to another human
    func isConnected(_ other: Human) -> Bool {
        return uidxList.intersection(other.uidxList).count > 0
    }
    
    // count number of body parts identified
    func partCount() -> Int {
        return self.bodyParts.count
    }
    
    // $0 is the first argument maps to the body part
    func getMaxScore() -> Double {
        return max(self.bodyParts.map{ $0.value.score })
    }
    
}
