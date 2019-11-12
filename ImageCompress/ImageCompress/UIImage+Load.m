//
//  UIImage+Load.m
//  ImageCompress
//
//  Created by 聂宽 on 2019/9/18.
//  Copyright © 2019 聂宽. All rights reserved.
//

#import "UIImage+Load.h"

// 每个像素占4个字节大小 共32位
static const size_t kBytesPerPixel = 4;
//每个通道由8位组成
static const size_t kBitsPerComponent = 8;

static const CGFloat kDestImageSizeMB = 60.0f;
static const CGFloat kSourceImageTileSizeMB = 20.0f;
// 每MB存在的字节数
static const CGFloat kBytesPerMB = 1024.0f * 1024.0f;
// 每MB存在的像素数
static const CGFloat kPixelsPerMB = kBytesPerMB / kBytesPerPixel;

// 压缩目标总像素数
static const CGFloat kDestTotalPixels = kDestImageSizeMB * kPixelsPerMB;
static const CGFloat kTileTotalPixels = kSourceImageTileSizeMB * kPixelsPerMB;

static const CGFloat kDestSeemOverlap = 2.0f;

@implementation UIImage (Load)
// 根据url获取图片
+ (void)loadImage:(NSURL *)imgUrl complete:(nonnull LoadComplete)complete
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:imgUrl];
        NSLog(@"--------- %lukb", data.length / 1024);
        UIImage *image = [UIImage imageWithData:data];
        
        if (image != nil) {
            // 获取图片方向信息
            UIImageOrientation imgOrientation = [self imageOrientationFormImage:image];
            if (imgOrientation != UIImageOrientationUp) {
                // 如果图片方向不是默认向上，根据图片方向信息重新创建图片
                image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:imgOrientation];
            }
            if (complete) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(image);
                });
            }
        }
        
    });
}

/*
 获取图片方向
 img->imgData
 从图片data->CGImageSourceRef (CGImageSourceCreateWithData())
 根据获取图片源->propertis图片相关属性 （CGImageSourceCopyPropertiesAtIndex()）
 图片属性->kCGImagePropertyOrientation 取到方向值
 CFNumberRef->NSInteger->转成iOS里边的方向
 */
+ (UIImageOrientation)imageOrientationFormImage:(UIImage *)img
{
    UIImageOrientation result = UIImageOrientationUp;
    
    /**
     参数1：
     参数2：指定额外创建option字典。我们可以在options字典中包含的键来创建图像源。
     比如说
     kCGImageSourceTypeIdentifierHint
     kCGImageSourceShouldAllowFloat
     kCGImageSourceShouldCache
     kCGImageSourceCreateThumbnailFromImageIfAbsent
     kCGImageSourceCreateThumbnailFromImageAlways
     kCGImageSourceThumbnailMaxPixelSize
     kCGImageSourceCreateThumbnailWithTransform
     */
    // 对象中读取的图像源
    CGImageSourceRef imgSource = CGImageSourceCreateWithData((__bridge CFDataRef)UIImagePNGRepresentation(img), NULL);
    if (imgSource != NULL) {
        /**
         返回图像源中指定位置的图像的属性。
         参数1：一个图像的来源
         参数2：你想要获得的属性的索引。该指数是从零开始的。index参数设置获取第几张图像
         参数3：可以用来请求其他选项的字典。
         返回包含与图像相关联的属性的字典。请参见CGImageProperties，以获得可以在字典中使用的属性列表。
         CGImageProperties引用定义了代表图像I/O框架使用的图像特征的常量。
         */
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, NULL);
        if (properties) {
            CFTypeRef val;
            NSInteger exifOrientation;
            // 返回方向键值所对应的内容
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) {
                // 将CFNumber对象转换为指定类型的值
                CFNumberGetValue(val, kCFNumberNSIntegerType, &exifOrientation);
                //转换exif中信息的方向到iOS里面的方向
                switch (exifOrientation) {
                    case 1:
                        result = UIImageOrientationUp;
                        break;
                    case 3:
                        result = UIImageOrientationDown;
                        break;
                    case 8:
                        result = UIImageOrientationLeft;
                        break;
                    case 6:
                        result = UIImageOrientationRight;
                        break;
                    case 2:
                        result = UIImageOrientationUpMirrored;
                        break;
                    case 4:
                        result = UIImageOrientationDownMirrored;
                        break;
                    case 5:
                        result = UIImageOrientationLeftMirrored;
                        break;
                    case 7:
                        result = UIImageOrientationRightMirrored;
                        break;
                    default:
                        break;
                }
                CFRelease(val);
                CFRelease(properties);
            }
            CFRelease(imgSource);
        }
    }
    return result;
}

/*
 解码图片
 image->imgRef
 根据imgRef->colorSpaceRef颜色空间，宽，高
 获取的图片信息->创建位图上下文 （CGBitmapContextCreate()）
 在上下文->进行绘制 （CGContextDrawImage()）
 绘制后的上下文->创建biemap位图 （CGBitmapContextCreatImage()）
 得到CGImageRef->UIImage
 最后做释放操作
 */
+ (UIImage *)decodedImageFromImage:(UIImage *)image
{
    if (![UIImage shouldDecodeImage:image]) {
        return image;
    }
    @autoreleasepool {
        CGImageRef imgRef = image.CGImage;
        CGColorSpaceRef colorSpaceRef = [UIImage colorSpaceFromImageRef:imgRef];
        size_t width = CGImageGetWidth(imgRef);
        size_t height = CGImageGetHeight(imgRef);
        /*
         参数1：指向要呈现绘图的内存中目标的指针。这个内存块的大小至少应该是(bytesPerRow*height)字节。
         如果希望此函数为位图分配内存，则传递NULL。这将使您不必管理自己的内存，从而减少内存泄漏问题。
         参数2：所需宽度，以像素为单位
         参数3：所需高度
         参数4：用于内存中一个像素的每个组件的比特数
         参数5：位图中每一行使用的内存字节数。如果数据参数为NULL，传递值为0，则会自动计算值。
         参数6：颜色空间
          参数7：指定位图是否应该包含一个alpha通道、alpha通道在一个像素中的相对位置，以及关于像素组件是浮点数还是整数值的信息。
         指定alpha通道信息的常量使用CGImageAlphaInfo类型声明，可以安全地传递给该参数。
         您还可以传递与CGBitmapInfo类型相关联的其他常量。
         例如，如何指定颜色空间、每个像素的位元、每个像素的位元以及位图信息，请参阅图形上下文。
         */
        //kCGBitmapByteOrderDefault 是默认模式，对于iPhone 来说，采用的是小端模式
        CGContextRef contextRef = CGBitmapContextCreate(NULL,
                                                        width,
                                                        height,
                                                        kBitsPerComponent,
                                                        kBytesPerPixel * width,
                                                        colorSpaceRef,
                                                        kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        if (contextRef == NULL) {
            return image;
        }
        /**
         这里创建的contexts是没有透明因素的。在UI渲染的时候，实际上是把多个图层按像素叠加计算的过程，需要对每一个像素进行 RGBA 的叠加计算。
         当某个 layer 的是不透明的，也就是 opaque 为 YES 时，GPU 可以直接忽略掉其下方的图层，这就减少了很多工作量。
         这也是调用 CGBitmapContextCreate 时 bitmapInfo 参数设置为忽略掉 alpha 通道的原因。而且这里主要针对的就是解码图片成位图
         */
        CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imgRef);
        CGImageRef imgRefWithoutAlpha = CGBitmapContextCreateImage(contextRef);
        UIImage *imageWithoutAlpha = [[UIImage alloc] initWithCGImage:imgRefWithoutAlpha scale:image.scale orientation:image.imageOrientation];
        CGContextRelease(contextRef);
        CGImageRelease(imgRefWithoutAlpha);
        return imageWithoutAlpha;
    }
    return image;
}

+ (UIImage *)decodedAndCompressImageWithImage:(UIImage *)image
{
    if (![UIImage shouldDecodeImage:image]) {
        return image;
    }
    if (![UIImage shouldScaleDownImage:image]) {
        // 不支持压缩->调用解码返回
        return [UIImage decodedImageFromImage:image];
    }
    // 声明目标压缩上下文
    CGContextRef destContentRef;
    @autoreleasepool {
        CGImageRef imgRef = image.CGImage;
        // 原宽高
        size_t sourceWidth = CGImageGetWidth(imgRef);
        size_t sourceHeith = CGImageGetHeight(imgRef);
        float scale = kDestTotalPixels / (sourceWidth * sourceHeith);
        // 目标宽高
        size_t destWidth = sourceWidth * scale;
        size_t destHeight = sourceHeith * scale;
        
        // 获取颜色空间
        CGColorSpaceRef colorSpaceRef = [UIImage colorSpaceFromImageRef:imgRef];
        
        /*
         目标图片的空间
         指向要呈现绘图的内存中目标的指针。这个内存块的大小至少应该是(bytesPerRow*height)字节。
         如果希望此函数为位图分配内存，则传递NULL。这将使您不必管理自己的内存，从而减少内存泄漏问题。
         */
        void *destBitmapData = malloc(kBytesPerPixel * destWidth * destHeight);
        if (destBitmapData == nil) {
            return image;
        }
        // 创建位图上下文
        destContentRef = CGBitmapContextCreate(destBitmapData,
                                               destWidth,
                                               destHeight,
                                               kBitsPerComponent,
                                               destWidth * kBytesPerPixel,
                                               colorSpaceRef,
                                               kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        if (!destContentRef) {
            free(destBitmapData);
            return image;
        }
        /*9. 设置图像插值的质量为高，设置图形上下文的插值质量水平CGContextSetInterpolationQuality允许上下文以各种保真度水平内插像素。
         在这种情况下，kCGInterpolationHigh通过最佳结果*/
        CGContextSetInterpolationQuality(destContentRef, kCGInterpolationHigh);
        // 原图片方形单元
        /*
         图片3个矩形单元
         ******
         ******
         ******
         */
        CGRect sourceTile = CGRectZero;
        sourceTile.size.width = sourceWidth;
        sourceTile.size.height = kTileTotalPixels / sourceWidth;
        // 起始位置设置为0
        sourceTile.origin.x = 0;
        
        //同样的方式初始化目标图像的块
        CGRect destTile = CGRectZero;
        destTile.size.width = destWidth;
        destTile.size.height = scale * sourceTile.size.height;
        destTile.origin.x = 0;
        
        // 计算源图像与压缩后目标图像重叠的像素大小。这里就是按照sourceResolution.height和destResolution.height进行相比
        float sourceSeemOverlap = (kDestSeemOverlap / destHeight) * sourceHeith;
        CGImageRef sourceTileImageRef;
        
        // 计算一共有多少个这样的单元块
        int iterations = (int)(sourceHeith / sourceTile.size.height);
        int remainder = (int)sourceHeith % (int)sourceTile.size.height;
        if (remainder > 0) {
            iterations++;
        }
        // 定义一个 float 变量 sourceTitleHeightMinusOverlap 存放那个用来分割源图像，大小为 20 MB 的方块的高度。
        float sourceTileHeighMinusOverlap = sourceTile.size.height;
        // 用于切割源图像大小为 20 MB 的方块的高度加上源图像与源图像分割方块的像素重叠数
        sourceTile.size.height = sourceTile.size.height + sourceSeemOverlap;
        // 目标图像的分割方块的高度加上 kDestSeemOverlap（像素重叠数赋值为 2）
        destTile.size.height = destTile.size.height + kDestSeemOverlap;
        
        for (int y = 0; y < iterations; ++y) {
            @autoreleasepool {
                sourceTile.origin.y = y * sourceTileHeighMinusOverlap + sourceSeemOverlap;
                destTile.origin.y = destHeight - (( y + 1 ) * sourceTileHeighMinusOverlap * scale ) - kDestSeemOverlap;
                sourceTileImageRef = CGImageCreateWithImageInRect(imgRef, sourceTile);
                if (y == iterations - 1 && remainder ) {
                    // 没有整除剩下的部分
                    float dify = destTile.size.height;
                    destTile.size.height = CGImageGetHeight(sourceTileImageRef) * scale;
                    dify = dify - destTile.size.height;
                    destTile.origin.y = destTile.origin.y + dify;
                }
                // 绘制图像到图形上下文指定的destTile范围中
                CGContextDrawImage(destContentRef, destTile, sourceTileImageRef);
                CGImageRelease(sourceTileImageRef);
            }
        }
        CGImageRef destImgRef = CGBitmapContextCreateImage(destContentRef);
        CGContextRelease(destContentRef);
        if (destImgRef == NULL) {
            return image;
        }
        UIImage *destImg = [UIImage imageWithCGImage:destImgRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(destImgRef);
        if (destImg == nil) {
            return image;
        }
        return destImg;
    }
    return image;
}

/*
 是否解码图像
 */
+ (BOOL)shouldDecodeImage:(UIImage *)image
{
    BOOL result = YES;
    if (image == nil) {
        result = NO;
    }
    // 不能编码动画图片
    if (image.images != nil) {
        result = NO;
    }
    CGImageRef imgRef = image.CGImage;
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imgRef);
    
    BOOL hasAlpha = (alphaInfo == kCGImageAlphaFirst ||
                     alphaInfo == kCGImageAlphaLast ||
                     alphaInfo == kCGImageAlphaPremultipliedFirst ||
                     alphaInfo == kCGImageAlphaPremultipliedLast);
    if (hasAlpha) {
        result = NO;
    }
    return result;
}

// 是否支持压缩
+ (BOOL)shouldScaleDownImage:(nonnull UIImage *)image
{
    CGImageRef imgRef = image.CGImage;
    size_t width = CGImageGetWidth(imgRef);
    size_t height = CGImageGetHeight(imgRef);
    float sourceTotalPixels = width * height;
    float scale = kDestTotalPixels / sourceTotalPixels;
    if (scale < 0) {
        return YES;
    }else
    {
        return NO;
    }
}

+ (CGColorSpaceRef)colorSpaceFromImageRef:(CGImageRef)imgRef
{
    CGColorSpaceRef colorSpaceRef = CGImageGetColorSpace(imgRef);
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpaceRef);
    
    BOOL unsupportedColorSpace = (colorSpaceModel == kCGColorSpaceModelUnknown ||
                                  colorSpaceModel == kCGColorSpaceModelMonochrome ||
                                  colorSpaceModel == kCGColorSpaceModelCMYK ||
                                  colorSpaceModel == kCGColorSpaceModelIndexed);
    if (unsupportedColorSpace) {
        colorSpaceRef = CGColorSpaceCreateDeviceRGB();
        CFAutorelease(colorSpaceRef);
    }
    return colorSpaceRef;
}
@end

