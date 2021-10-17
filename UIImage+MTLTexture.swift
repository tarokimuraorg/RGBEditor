//
//  UIImage+MTLTexture.swift
//  RGBAEditor
//
//  Created by Taro Kimura on 2019/05/02.
//  Copyright © 2019 Taro Kimura. All rights reserved.
//

import UIKit
import MetalKit

extension UIImage {
    
    public convenience init?(mtlImage: MTLImage, scale inScale: CGFloat) {
        
        // MTLImageからMTLTextureを取得
        guard let mtlTexture = mtlImage.texture else {
            
            print(Errors.Line17)
            return nil
            
        }
        
        // MTLImageから画像のサイズを取得
        let mtlWidth = mtlImage.width
        let mtlHeight = mtlImage.height
        
        // MTLImageから画像データ一行あたりのバイト数を取得
        let mtlBytesPerRow = mtlImage.bytesPerRow
        
        // MTLImageから各カラーコンポーネント毎に割り当てられたビット数を取得
        let mtlBitsPerComponent = mtlImage.bitsPerComponent
        
        // MTLImageからビットマップ情報を取得
        let mtlBitmapInfo = mtlImage.bitmapInfo
        
        // MTLImageからカラースペースデータを取得
        let mtlColorSpace = mtlImage.colorSpace
        
        // MTLImageから編集する画像の範囲を取得
        let region = mtlImage.region
        
        // 画像データのバイト数を求める
        let bytesCount = mtlHeight * mtlBytesPerRow
        
        // 空の配列[UInt8]を作成
        var bytes = [UInt8](repeating: 0, count: bytesCount)
        
        // MTLTextureから画像のバイトデータを取得し、作成した空の配列に代入
        mtlTexture.getBytes(&bytes, bytesPerRow: mtlBytesPerRow, from: region, mipmapLevel: 0)
        
        // CGContextを作成
        guard let outCGContext = CGContext.init(data: &bytes, width: mtlWidth, height: mtlHeight, bitsPerComponent: mtlBitsPerComponent, bytesPerRow: mtlBytesPerRow, space: mtlColorSpace, bitmapInfo: mtlBitmapInfo.rawValue) else {
            
            print(Errors.Line53)
            return nil
            
        }
        
        // CGContextからCGImageを作成
        guard let outCGImage = outCGContext.makeImage() else {
            
            print(Errors.Line61)
            return nil
            
        }
        
        let outOrientation = mtlImage.orientation
        
        // CGImageをUIImageに変換
        
        /*
         
        scale: The scale factor to assume when interpreting the image data. Applying a scale factor of 1.0 results in an image whose size matches the pixel-based dimensions of the image. Applying a different scale factor changes the size of the image as reported by the size property.
         
         */
        self.init(cgImage: outCGImage, scale: inScale, orientation: outOrientation)
        
    }
    
    enum Errors: String {
        
        case Line17 = "UIImage+MTLTexture: Error: Line 17: Failed to get a MTLTexture object."
        case Line53 = "UIImage+MTLTexture: Error: Line 53: Failed to make a CGContext object."
        case Line61 = "UIImage+MTLTexture: Error: Line 61: Failed to make a CGImage object."
        
    }
    
}
