//
//  PixelMod.swift
//  PhaseI
//
//  Created by Lara Riparip on 16.07.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

import UIKit

//extension ViewController {
//    func imageFromRGBA32Bitmap(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
//        guard width > 0 && height > 0 else { return nil }
//        guard pixels.count == width * height else { return nil }
//
//        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
//        let bitsPerComponent = 8
//        let bitsPerPixel = 32
//
//        var data = pixels // Copy to mutable []
//        guard let providerRef = CGDataProvider(data: NSData(bytes: &data, length: data.count * 4)
//            )
//            else { return nil }
//
//
//        guard let cgim = CGImage(
//            width: width,
//            height: height,
//            bitsPerComponent: bitsPerComponent,
//            bitsPerPixel: bitsPerPixel,
//            bytesPerRow: width * 4,
//            space: rgbColorSpace,
//            bitmapInfo: bitmapInfo,
//            provider: providerRef,
//            decode: nil,
//            shouldInterpolate: false,
//            intent: .defaultIntent
//            )
//            else { return nil }
//
//        print ("Blue has been made")
//
//        modifiedImage = UIImage(cgImage: cgim)
//        return modifiedImage
//    }
//
//}

//extension ViewController {
//    func makingBlue(pixels: [UInt8], width: Int, height: Int) -> UIImage? {
//        //let dataSize = width * height * 4
//        //var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
//        let context = CGContext(data: nil,
//                                width: width,
//                                height: height,
//                                bitsPerComponent: 8,
//                                bytesPerRow: 4 * width,
//                                space: CGColorSpaceCreateDeviceRGB(),
//                                bitmapInfo: bitmapInfo.rawValue)
//
//        let blueImage = context!.makeImage()
//
//        if blueImage != nil {
//            print("Blue image made: \(pixels.prefix(12))")
//        }
//        return UIImage(cgImage: blueImage!)
//    }
//}
