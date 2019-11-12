//
//  UIImage+Load.h
//  ImageCompress
//
//  Created by 聂宽 on 2019/9/18.
//  Copyright © 2019 聂宽. All rights reserved.
//


#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^LoadComplete)(UIImage *image);
@interface UIImage (Load)

//https://pics6.baidu.com/feed/14ce36d3d539b600c561b9058d9d402fc75cb72c.png?token=ae6c6b929cdc899184b8d70a425a75e0&s=EAB00CC73C1424CE44052C3A03001013
+(void)loadImage:(NSURL *)imgUrl complete:(LoadComplete)complete;

+ (UIImage *)decodedImageFromImage:(UIImage *)image;
@end

NS_ASSUME_NONNULL_END
