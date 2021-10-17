//
//  MTLImage.swift
//  TestCompute
//
//  Created by Taro Kimura on 2019/04/16.
//  Copyright © 2019 Taro Kimura. All rights reserved.
//

import UIKit
import MetalKit

public class MTLImage {
    
    public var texture: MTLTexture? = nil
    
    public var colorSpace: CGColorSpace
    public var bitmapInfo: CGBitmapInfo
    
    public var width: Int
    public var height: Int
    public var region: MTLRegion
    
    public var bytesPerRow: Int
    public var bitsPerComponent: Int
    
    public var orientation: UIImage.Orientation
    
    private var cgImage: CGImage
    
    private var threadsPerThreadgroup: MTLSize
    private var alphaLocation: Int
    
    private var device: MTLDevice
    private var function: MTLFunction
    private var buffer: MTLCommandBuffer
    private var pipeline: MTLComputePipelineState
    
    // MTLImageを初期化
    init?(image: UIImage, device inDevice: MTLDevice, function inFunction: MTLFunction, buffer inBuffer: MTLCommandBuffer, pipeline inPipeline: MTLComputePipelineState) {
        
        self.orientation = image.imageOrientation
        
        // 画像データをpng形式に変換
        guard let inputData = image.pngData() else {
            
            print(Errors.Line44)
            return nil
            
        }
        
        //UIImageをCFDataに変換
        let inData = inputData as CFData
        
        guard let inSource = CGImageSourceCreateWithData(inData, nil) else {
            
            print(Errors.Line54)
            return nil
            
        }
        
        // CGImageSourceからCGImageを作成
        guard let inCGImage = CGImageSourceCreateImageAtIndex(inSource, 0, nil) else {
            
            print(Errors.Line62)
            return nil
            
        }
        
        self.cgImage = inCGImage
        
        // CGImageからCGColorSpaceを取得
        guard let space = self.cgImage.colorSpace else {
            
            print(Errors.Line72)
            return nil
            
        }
        
        // 取得したCGColorSpaceを代入
        self.colorSpace = space
        
        // CGColorSpaceからCGColorSpaceModelを取得
        let colorSpaceModel = self.colorSpace.model
        
        // 取得した画像の[Color Space]がRGB以外なら処理を終了: nilを返す
        if colorSpaceModel != .rgb {
            
            print(Errors.Line86)
            return nil
            
        }
        
        // 1ピクセルあたりのビット数を取得
        let bitsPerPixel = self.cgImage.bitsPerPixel
        
        // 1ピクセルあたりのバイト数を計算し、代入
        let bytesPerPixel = bitsPerPixel / 8
        
        // ピクセルがRGBA(または、ARGB)であることを確認する
        if bytesPerPixel != 4 {
            
            print(Errors.Line100)
            return nil
            
        }
        
        // 画像データ一行あたりのバイト数を取得
        self.bytesPerRow = self.cgImage.bytesPerRow
        
        // 各カラーコンポーネント毎に割り当てられたビット数を取得
        self.bitsPerComponent = self.cgImage.bitsPerComponent
        
        // 画像サイズを取得
        self.width = self.cgImage.width
        self.height = self.cgImage.height
        
        self.device = inDevice
        self.function = inFunction
        self.buffer = inBuffer
        self.pipeline = inPipeline
        
        // Calculating threads per threadgroup.
        let threadgroupWidth = self.pipeline.threadExecutionWidth
        let threadgroupHeight = self.pipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth
        
        self.threadsPerThreadgroup = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1)
        
        // ByteOrderInfoを取得
        let byteOrderInfo = self.cgImage.byteOrderInfo
        
        // バイト順をチェック (ARGB or RGBAであることを保証するため)
        if byteOrderInfo != .order32Big && byteOrderInfo != .orderDefault {
            
            print(Errors.Line132)
            return nil
            
        }
        
        // AlphaInfoを取得
        let alphaInfo = self.cgImage.alphaInfo
        
        switch alphaInfo {
            
        // 画像データがARGBの順で並んでいる場合
        case .first, .premultipliedFirst, .noneSkipFirst:
            
            // BitmapInfoを作成
            self.bitmapInfo = CGBitmapInfo(rawValue: (CGImageByteOrderInfo.order32Big.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue))
            
            self.alphaLocation = Int(AAPLAlphaLocationFirst.rawValue)
            
        // 画像データがRGBAの順で並んでいる場合
        case .last, .premultipliedLast, .noneSkipLast:
            
            // BitmapInfoを作成
            self.bitmapInfo = CGBitmapInfo(rawValue: (CGImageByteOrderInfo.order32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            
            self.alphaLocation = Int(AAPLAlphaLocationLast.rawValue)
            
        default:
            
            print(Errors.Line142)
            return nil
            
        }
        
        // 画像の編集範囲を指定
        self.region = MTLRegion.init(origin: MTLOrigin.init(x: 0, y: 0, z: 0), size: MTLSize.init(width: self.width, height: self.height, depth: 1))
        
        // 二つのテクスチャを画像の入出力用としてそれぞれ作成する
        guard let textures = self.ioTextures(region: self.region) else {
            
            print(Errors.Line171)
            return nil
            
        }
        
        // 作成したMTLCommandBufferに値をセットしてコミットする
        self.commitBuffer(inTexture: textures.input, outTexture: textures.output)
        
        // 出力用のMTLTextureをセット
        self.texture = textures.output
        
    }
   
    // MTLDeviceから二つのMTLTexture（画像データの入出力用）を作成する
    private func ioTextures(region inRegion: MTLRegion) -> (input: MTLTexture, output: MTLTexture)? {
        
        // ディフォルトのMTLTextureDescriptorを二つ作成。（画像データの入出力用）
        let descriptors = self.ioDescriptors
        
        // 入力用のMTLTextureを作成
        guard let inputTexture = self.device.makeTexture(descriptor: descriptors.input) else {
            
            print(Errors.Line193)
            return nil
            
        }
        
        // 入力用のMTLTextureに画像データをセットする
        inputTexture.replace(region: inRegion, mipmapLevel: 0, withBytes: self.bytes, bytesPerRow: self.bytesPerRow)
        
        // 出力用のMTLTextureを作成
        guard let outputTexture = self.device.makeTexture(descriptor: descriptors.output) else {
            
            print(Errors.Line204)
            return nil
            
        }
        
        return (inputTexture, outputTexture)
        
    }
    
    // デフォルトのMTLTextureDescriptorを二つ（画像データの入出力用）作成する。
    private var ioDescriptors: (input: MTLTextureDescriptor, output: MTLTextureDescriptor) {
        
        // 入力用のMTLTextureDescriptorを作成
        let inputDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.init()
        
        // 入力用のMTLTextureDescriptorに値をセットする
        inputDescriptor.textureType = MTLTextureType.type2D
        inputDescriptor.pixelFormat = MTLPixelFormat.rgba8Unorm
        inputDescriptor.width = self.width
        inputDescriptor.height = self.height
        inputDescriptor.usage = MTLTextureUsage.shaderRead
        
        // 出力用のMTLTextureDescriptorを作成
        let outputDescriptor: MTLTextureDescriptor = MTLTextureDescriptor.init()
        
        // 出力用のMTLTextureDescriptorに値をセットする
        outputDescriptor.textureType = MTLTextureType.type2D
        outputDescriptor.pixelFormat = MTLPixelFormat.rgba8Unorm
        outputDescriptor.width = self.width
        outputDescriptor.height = self.height
        outputDescriptor.usage = MTLTextureUsage.shaderWrite
        
        return (inputDescriptor, outputDescriptor)
        
    }
    
    // CGImageを配列[UInt8]に変換する
    private var bytes: [UInt8] {
        
        // 画像データのサイズを求める
        let inputCount = self.height * self.bytesPerRow
        
        // 空の配列[UInt8]を作成
        var outputBytes = [UInt8](repeating: 0, count: inputCount)
        
        // CGDataProviderを作成
        guard let provider = self.cgImage.dataProvider else {
            
            print(Errors.Line252)
            return outputBytes
            
        }
        
        // CGDataProviderのデータをコピーする
        guard let data = provider.data else {
            
            print(Errors.Line260)
            return outputBytes
            
        }
        
        // コピーしたデータの長さを取得
        let inputLength = CFDataGetLength(data)
        
        // 使用するデータの範囲を指定
        let range = CFRange(location: 0, length: inputLength)
        
        // コピーしたデータを空の配列[UInt8]に代入する
        CFDataGetBytes(data, range, &outputBytes)
        
        return outputBytes
        
    }
    
    // MTLTextureを作成
    private func commitBuffer(inTexture inputTexture: MTLTexture, outTexture outputTexture: MTLTexture) {
        
        // 各スレッドグループ毎のスレッドの幅を求める
        let threadgroup_width = (inputTexture.width + self.threadsPerThreadgroup.width - 1) / self.threadsPerThreadgroup.width
        
        // 各スレッドグループ毎のスレッドの高さを求める
        let threadgroup_height = (inputTexture.height + self.threadsPerThreadgroup.height - 1) / self.threadsPerThreadgroup.height
        
        // 各次元に与えられたスレッドの数を代入
        let threadgroupCount = MTLSizeMake(threadgroup_width, threadgroup_height, 1)
        
        /* AAPLAlphaLocationを配列の中に格納
         * ピクセルデータの順序がARGBの場合: aaplAlphaLocation = 0
         *                   RGBAの場合: aaplAlphaLocation = 1
         */
        let aLocation: [Int] = [self.alphaLocation]
        
        // 配列aLocationの長さをバイトで換算する
        let aLocationBytes = MemoryLayout<UInt32>.stride
        
        // AAPLAlphaInfoをAAPLShader内の関数で使用するため、MTLBufferを作成
        guard let alphaInfoBuffer = self.device.makeBuffer(bytes: aLocation, length: aLocationBytes, options: []) else {
            
            print(Errors.Line302)
            return
            
        }
        
        // MTLComputeCommandEncoderを作成
        guard let inputEncoder: MTLComputeCommandEncoder = self.buffer.makeComputeCommandEncoder() else {
            
            print(Errors.Line310)
            return
            
        }
        
        // MTLComputeCommandEncoderに値をセットする
        inputEncoder.setComputePipelineState(self.pipeline)
        
        inputEncoder.setTexture(inputTexture, index: Int(AAPLTextureIndexInput.rawValue))
        inputEncoder.setTexture(outputTexture, index: Int(AAPLTextureIndexOutput.rawValue))
        
        inputEncoder.setBuffer(alphaInfoBuffer, offset: 0, index: 0)
        
        inputEncoder.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: self.threadsPerThreadgroup)
        inputEncoder.endEncoding()
        
        // MTLCommandBufferをコミットする
        self.buffer.commit()
        self.buffer.waitUntilCompleted()
        
    }
    
    enum Errors: String {
        
        case Line44 = "MTLImage: Error: Line 44: Failed to convert image data to png data."
        case Line54 = "MTLImage: Error: Line 54: Failed to make a CGImageSource object."
        case Line62 = "MTLImage: Error: Line 62: Failed to make a CGImage object."
        case Line72 = "MTLImage: Error: Line 72: Failed to get a CGColorSpace object."
        case Line86 = "MTLImage: Error: Line 86: The Color Space of this image is not RGB."
        case Line100 = "MTLImage: Error: Line 100: The number of bits used in memory for each pixel of this image is not 4."
        case Line132 = "MTLImage: Error: Line 132: The byte order info has a unsupported value."
        case Line142 = "MTLImage: Error: Line 142 : This image does not contain any alpha channel or the alpha component is stored in the most/the least significant bits of each pixel."
        case Line171 = "MTLImage: Error: Line 171: Failed to make a MTLTexture object for inputing/outputing image data."
        case Line193 = "MTLImage: Error: Line 193: Failed to make a MTLTexture object for inputing image data."
        case Line204 = "MTLImage: Error: Line 204: Failed to make a MTLTexture object for outputing image data."
        case Line252 = "MTLImage: Error: Line 252: Failed to make a CGDataProvider object."
        case Line260 = "MTLImage: Error: Line 260: Failed to copy the provider’s data."
        case Line302 = "MTLImage: Error: Line 301: Failed to make a MTLBuffer object."
        case Line310 = "MTLImage: Error: Line 309: Failed to make a MTLComputeCommandEncoder object."
        
    }
    
}
