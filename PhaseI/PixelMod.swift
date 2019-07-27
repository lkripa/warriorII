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


// MARK: - Tap function to retrieve pixel information at a certain point
extension UIImageView {
    func getPixelColorAtPoint(point: CGPoint, sourceView: UIImageView) -> UIColor {
        let pixel = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: pixel,
                                width: 1,
                                height: 1,
                                bitsPerComponent: 8,
                                bytesPerRow: 4,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)
        
        context!.translateBy(x: -point.x, y: -point.y)
        
        
        sourceView.layer.render(in: context!)
        let color: UIColor = UIColor(red: CGFloat(pixel[0])/255.0,
                                     green: CGFloat(pixel[1])/255.0,
                                     blue: CGFloat(pixel[2])/255.0,
                                     alpha: CGFloat(pixel[3])/255.0)
        
        pixel.deallocate()
        return color
    }
}

// MARK: - Function to output pixel data
extension CGImage {
    func pixelData() { //}-> [UInt8]? {
        let dataSize = self.width * self.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(self.width),
                                height: Int(self.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(self.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        context?.draw(self, in: CGRect(x: 0, y: 0, width: self.width, height: self.height))
        
        //        for i in stride(from: pixelData.index(after: 3), to: pixelData.endIndex, by: 4){
        //            pixelData[i] = 0 // the 255 replaces index 2 which is blue
        //        }
        print ("Width: \(self.width), Height: \(self.height)")
        print ("Pixel Data: \(pixelData.suffix(12))")
        //return (pixelData)
    }
}
