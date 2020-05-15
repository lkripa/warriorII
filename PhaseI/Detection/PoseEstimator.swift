//
//  PoseEstimator.swift
//  PhaseI
//
//  Created by Lara Riparip on 22.07.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import Foundation

open class PoseEstimator {
    init(_ imageWidth: Int,_ imageHeight: Int){
        heatRows = imageWidth / 8
        heatColumns = imageHeight / 8
    } // image size reduced by 8
    
    // openCV for matrix wrapper
    let opencv = OpenCVWrapper()
    
    var heatRows = 0
    var heatColumns = 0
    
    let nmsThreshold = 0.1
    let localPAFThreshold = 0.1
    let pafCountThreshold = 5 // 5 joints
    let partCountThreshold = 4.0
    let partScoreThreshold = 0.6
    
    func estimate (_ mm: Array<Double>) -> [Human] {
        
        // first 19 are for  joint confidence heatmaps
        // next 38 are for x and y joint part affinity field maps
        let separateLen = 19*heatRows*heatColumns
        let pafMatrix = Matrix<Double>(rows: 38, columns: heatRows*heatColumns,
                                    elements: Array<Double>(mm[separateLen..<mm.count]))
        
        var heatmapData = Array<Double>(mm[0..<separateLen])
        
        opencv.matrixMin(
            &heatmapData,
            data_size: Int32(heatmapData.count),
            data_rows: 19,
            heat_rows: Int32(heatRows)
        )
        
        //matrix transformation of joint confidence heatmaps
        let heatMatrix = Matrix<Double>(rows: 19, columns: heatRows*heatColumns, elements: heatmapData )
        
        // determine NMS threshold
        var _nmsThreshold = max(mean(heatmapData) * 4.0, nmsThreshold)
        _nmsThreshold = min(_nmsThreshold, 0.3)
        
        // extract interesting coordinates using NMS
        let coords : [[(Int,Int)]] = (0..<heatMatrix.rows-1).map { i in
            var nms = Array<Double>(heatMatrix.row(i))
            nonMaxSuppression(&nms, dataRows: Int32(heatColumns),
                              maskSize: 5, threshold: _nmsThreshold)
            return nms.enumerated().filter{ $0.1 > _nmsThreshold }.map { x in
                  ( x.0 / heatRows , x.0 % heatRows )
            }
        }
        
        // score pairs
        let pairsByConn = zip(CocoPairs, CocoPairsNetwork).reduce(into: [Connection]()) {
            $0.append(contentsOf: scorePairs(
                $1.0.0, $1.0.1,
                coords[$1.0.0], coords[$1.0.1],
                Array<Double>(pafMatrix.row($1.1.0)), Array<Double>(pafMatrix.row($1.1.1)),
                &heatmapData,
                rescale: (1.0 / CGFloat(heatColumns), 1.0 / CGFloat(heatRows))
            ))
        }
        
        // merge pairs to human
        // pairs_by_conn is sorted by CocoPairs (part importance) and Score between Parts.
        var humans = pairsByConn.map{ Human([$0]) }
        if humans.count == 0 {
            return humans
        }
        
        // checking that joints are connected to only one human each
        while true {
            var items: (Int,Human,Human)!
            for x in combinations([[Int](0..<humans.count), [Int](1..<humans.count)]){
                if x[0] == x[1] {
                    continue
                }
                let k1 = humans[x[0]]
                let k2 = humans[x[1]]
                
                if k1.isConnected(k2){
                    items = (x[1],k1,k2)
                    break
                }
            }
            
            if items != nil {
                items.1.merge(items.2)
                humans.remove(at: items.0)
            } else {
                break
            }
        }
        // $0 is the first element and $1 is the second element
        // sort the humans by the biggest to the smallest part count
        humans = humans.sorted(by:{ $0.partCount() > $1.partCount() })
        
        // keep the most built human
        humans = [humans[0]]
        
        // reject by subset count
        humans = humans.filter{ $0.partCount() >= pafCountThreshold }
        
        // reject by subset max score
        humans = humans.filter{ $0.getMaxScore() >= partScoreThreshold }
        return humans
    }
    
// MARK: - estimate() functions
    
    // to check array with one human to another human
    func combinations<T>(_ arr: [[T]]) -> [[T]] {
        return arr.reduce([[]]) {
            var x = [[T]]()
            for elem1 in $0 {
                for elem2 in $1 {
                    x.append(elem1 + [elem2])
                }
            }
            return x
        }
    }
    // NMS function from openCV
    func nonMaxSuppression(_ data: inout [Double],
                           dataRows: Int32,
                           maskSize: Int32,
                           threshold: Double) {
        
        opencv.maximum_filter(
            &data,
            data_size: Int32(data.count),
            data_rows: dataRows,
            mask_size: maskSize,
            threshold: threshold
        )
    }
    
    func getScore(_ x1 : Int,_ y1: Int,_ x2: Int,_ y2: Int,_ pafMatX: [Double],_ pafMatY: [Double]) -> (Double,Int) {
        let __numInter = 10
        let __numInterF = Double(__numInter)
        let dx = Double(x2 - x1)
        let dy = Double(y2 - y1)
        let normVec = sqrt(pow(dx,2) + pow(dy,2))
        
        if normVec < 1e-4 {
            return (0.0, 0)
        }
        let vx = dx / normVec
        let vy = dy / normVec
        
        let xs = (x1 == x2) ? Array(repeating: x1 , count: __numInter)
            : stride(from: Double(x1), to: Double(x2), by: Double(dx / __numInterF)).map {Int($0+0.5)}
            // $0 = first argument
        
        let ys = (y1 == y2) ? Array(repeating: y1 , count: __numInter)
            : stride(from: Double(y1), to: Double(y2), by: Double(dy / __numInterF)).map {Int($0+0.5)}
        
        // without vectorization
        var pafXs = Array<Double>(repeating: 0.0 , count: xs.count)
        var pafYs = Array<Double>(repeating: 0.0 , count: ys.count)
        for (idx, (mx, my)) in zip(xs, ys).enumerated(){
            pafXs[idx] = pafMatX[my*heatRows+mx]
            pafYs[idx] = pafMatY[my*heatRows+mx]
        }
        
        let localScores = pafXs * vx + pafYs * vy
        var thidxs = localScores.filter({$0 > localPAFThreshold})
        
        if (thidxs.count > 0){
            thidxs[0] = 0.0
        }
        return (sum(thidxs), thidxs.count)
    }
    
    // score the confidence of a pair of two joints; check for pafCountThreshold and score threshold
    func scorePairs(_ partIdx1: Int,_ partIdx2: Int,
                    _ coordList1: [(Int,Int)],_ coordList2: [(Int,Int)],
                    _ pafMatX: [Double],_ pafMatY: [Double],
                    _ heatmap: inout [Double],
                    rescale: (CGFloat,CGFloat) = (1.0, 1.0)) -> [Connection] {
        
        var connectionTmp = [Connection]()
        for (idx1,(y1,x1)) in coordList1.enumerated() {
            for (idx2,(y2,x2)) in coordList2.enumerated() {
                let (score, count) = getScore(x1, y1, x2, y2, pafMatX, pafMatY)
                if count < pafCountThreshold || score <= 0.0 {
                    continue
                }
                
                connectionTmp.append(Connection(
                    score: score,
                    partIdx1: partIdx1, partIdx2: partIdx2,
                    idx1: idx1, idx2: idx2,
                    coord1: (CGFloat(x1) * rescale.0, CGFloat(y1) * rescale.1),
                    coord2: (CGFloat(x2) * rescale.0, CGFloat(y2) * rescale.1),
                    score1: heatmap[partIdx1*y1*x1],
                    score2: heatmap[partIdx2*y2*x2]
                ))
            }
        }
        var connection = [Connection]()
        // Multiple score cuts
        var usedIdx1 = [Int]()
        var usedIdx2 = [Int]()
        connectionTmp.sorted{ $0.score > $1.score }.forEach { conn in
            // check not connected
            if usedIdx1.contains(conn.idx1) || usedIdx2.contains(conn.idx2) {
                return
            }
            connection.append(conn)
            usedIdx1.append(conn.idx1)
            usedIdx2.append(conn.idx2)
        }
        return connection
    }
}

