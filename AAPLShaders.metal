//
//  AAPLShaders.metal
//  TestCompute
//
//  Created by Taro Kimura on 2019/04/06.
//  Copyright © 2019 Taro Kimura. All rights reserved.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;
#import "AAPLShaderTypes.h"

// Rec. 709 luma values for grayscale image conversion
constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

// PNG画像によってalpha値の位置が違うため、この構造体で成形している
typedef struct {
    
    // 0.0 =< red, green, blue, alpha =< 1.0
    half red;
    half green;
    half blue;
    
} pixel;

kernel void
ConvertToAlicescale(texture2d<half, access::read>  inTexture  [[texture(AAPLTextureIndexInput)]],
           texture2d<half, access::write> outTexture [[texture(AAPLTextureIndexOutput)]],
           device uint                    *alphaLocation [[ buffer(0) ]],
           uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    // 画像のピクセルデータを取得
    half4 inColor  = inTexture.read(gid);
    
    //pixel inputRGB;
    pixel inRGB;
    
    // alpha値以外のピクセルデータ(Red, Green, Blue)を代入
    switch (alphaLocation[0]) {
            
        case AAPLAlphaLocationFirst:
            
            inRGB = pixel{inColor[1], inColor[2], inColor[3]};
            break;
            
        case AAPLAlphaLocationLast:
            
            inRGB = pixel{inColor[0], inColor[1], inColor[2]};
            break;
            
        default:
            return;
    }
    
    // RGB値を編集 ---------------------------
    half red = inRGB.red;
    half green = inRGB.green;
    half blue = inRGB.blue;
    
    half rawHue;
    half refHue = 25.0;
    
    half maxRGB = max3(red, green, blue);
    half minRGB = min3(red, green, blue);
    
    if (maxRGB == minRGB) {
        
        rawHue = 0.0;
        
    } else {
        
        if (maxRGB == red) {
            
            rawHue = green - blue;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        } else if (maxRGB == green) {
            
            rawHue = blue - red;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            rawHue = rawHue + 120.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        } else {
            
            rawHue = red - green;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            rawHue = rawHue + 240.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        }
        
    }
    
    if (rawHue >= 180.0 && rawHue <= 240.0) {
        
        refHue = 194.0;
        
        blue = maxRGB;
        red = minRGB;
        
        green = 240.0 - refHue;
        green = green / 60.0;
        green = green * (maxRGB - minRGB);
        green = green + minRGB;
        
    } else {
        
        red = maxRGB;
        blue = minRGB;
        
        green = refHue / 60.0;
        green = green * (maxRGB - minRGB);
        green = green + minRGB;
        
    }
    
    // --------------------------------------
    
    // 編集したRGB値を含むピクセルデータを代入する変数
    pixel outRGB = pixel{red, green, blue};
    
    switch (alphaLocation[0]) {
            
        case AAPLAlphaLocationFirst:
            
            outTexture.write(half4(inColor[0], outRGB.red, outRGB.green, outRGB.blue), gid);
            break;
            
        case AAPLAlphaLocationLast:
            
            outTexture.write(half4(outRGB.red, outRGB.green, outRGB.blue, inColor[3]), gid);
            break;
            
        default:
            
            outTexture.write(inColor, gid);
            break;
            
    }
    
}

kernel void
ConvertToPeachscale(texture2d<half, access::read>  inTexture  [[texture(AAPLTextureIndexInput)]],
           texture2d<half, access::write> outTexture [[texture(AAPLTextureIndexOutput)]],
           device uint                    *alphaLocation [[ buffer(0) ]],
           uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
    
    // 画像のピクセルデータを取得
    half4 inColor  = inTexture.read(gid);
    
    //pixel inputRGB;
    pixel inRGB;
    
    // alpha値以外のピクセルデータ(Red, Green, Blue)を代入
    switch (alphaLocation[0]) {
            
        case AAPLAlphaLocationFirst:
            
            inRGB = pixel{inColor[1], inColor[2], inColor[3]};
            break;
            
        case AAPLAlphaLocationLast:
            
            inRGB = pixel{inColor[0], inColor[1], inColor[2]};
            break;
            
        default:
            return;
    }
    
    // RGB値を編集 ---------------------------
    half red = inRGB.red;
    half green = inRGB.green;
    half blue = inRGB.blue;
    
    half rawHue;
    half refHue = 339.0;
    
    half maxRGB = max3(red, green, blue);
    half minRGB = min3(red, green, blue);
    
    if (maxRGB == minRGB) {
        
        rawHue = 0.0;
        
    } else {
        
        if (maxRGB == red) {
            
            rawHue = green - blue;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        } else if (maxRGB == green) {
            
            rawHue = blue - red;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            rawHue = rawHue + 120.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        } else {
            
            rawHue = red - green;
            rawHue = rawHue / (maxRGB - minRGB);
            rawHue = rawHue * 60.0;
            rawHue = rawHue + 240.0;
            
            if (rawHue < 0.0) {
                rawHue = rawHue + 360.0;
            }
            
        }
        
    }
    
    if (rawHue >= 0.0 && rawHue <= 60.0) {
        
        refHue = 25.0;
        
        red = maxRGB;
        
        green = green / 60.0;
        green = green * (maxRGB - minRGB);
        green = green + minRGB;
        
        blue = minRGB;
        
    } else {
        
        red = maxRGB;
        green = minRGB;
        
        blue = 360.0 - refHue;
        blue = blue / 60.0;
        blue = blue * (maxRGB - minRGB);
        blue = blue + minRGB;
        
    }
    
    // --------------------------------------
    
    // 編集したRGB値を含むピクセルデータを代入する変数
    pixel outRGB = pixel{red, green, blue};
    
    switch (alphaLocation[0]) {
            
        case AAPLAlphaLocationFirst:
            
            outTexture.write(half4(inColor[0], outRGB.red, outRGB.green, outRGB.blue), gid);
            break;
            
        case AAPLAlphaLocationLast:
            
            outTexture.write(half4(outRGB.red, outRGB.green, outRGB.blue, inColor[3]), gid);
            break;
            
        default:
            
            outTexture.write(inColor, gid);
            break;
            
    }
    
}
    
kernel void
ConvertToGrayscale(texture2d<half, access::read>  inTexture  [[texture(AAPLTextureIndexInput)]],
                   texture2d<half, access::write> outTexture [[texture(AAPLTextureIndexOutput)]],
                   device uint                    *alphaLocation [[ buffer(0) ]],
                   uint2                          gid         [[thread_position_in_grid]])
{
    // Check if the pixel is within the bounds of the output texture
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        // Return early if the pixel is out of bounds
        return;
    }
        
    // 画像のピクセルデータを取得
    half4 inColor  = inTexture.read(gid);
        
    pixel inputRGB;
        
    // alpha値以外のピクセルデータ(Red, Green, Blue)を代入
    switch (alphaLocation[0]) {
        case AAPLAlphaLocationFirst:
            inputRGB = pixel{inColor[1], inColor[2], inColor[3]};
            break;
        case AAPLAlphaLocationLast:
            inputRGB = pixel{inColor[0], inColor[1], inColor[2]};
            break;
        default:
            return;
    }
        
    // RGB値を編集 ---------------------------
        
    half red = inputRGB.red * kRec709Luma[0];
    half green = inputRGB.green * kRec709Luma[1];
    half blue = inputRGB.blue * kRec709Luma[2];
        
    half gray = red + green + blue;
        
    // --------------------------------------
        
    // 編集したRGB値を含むピクセルデータを代入
    pixel outputRGB = pixel{gray, gray, gray};
        
    switch (alphaLocation[0]) {
        case AAPLAlphaLocationFirst:
            outTexture.write(half4(inColor[0], outputRGB.red, outputRGB.green, outputRGB.blue), gid);
            break;
        case AAPLAlphaLocationLast:
            outTexture.write(half4(outputRGB.red, outputRGB.green, outputRGB.blue, inColor[3]), gid);
            break;
        default:
            return;
    }
    
}
