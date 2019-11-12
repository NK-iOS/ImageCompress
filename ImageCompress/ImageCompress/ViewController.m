//
//  ViewController.m
//  ImageCompress
//
//  Created by 聂宽 on 2019/9/18.
//  Copyright © 2019 聂宽. All rights reserved.
//

#import "ViewController.h"
#import "UIImage+Load.h"
#import "Personal.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *urlStr = @"https://pics6.baidu.com/feed/14ce36d3d539b600c561b9058d9d402fc75cb72c.png?token=ae6c6b929cdc899184b8d70a425a75e0&s=EAB00CC73C1424CE44052C3A03001013";
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:imgView];
    [UIImage loadImage:[NSURL URLWithString:urlStr] complete:^(UIImage * _Nonnull image) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *img = [UIImage decodedImageFromImage:image];
            dispatch_async(dispatch_get_main_queue(), ^{
                imgView.image = img;
                NSData *data = UIImagePNGRepresentation(img);
                NSLog(@"--------- %lukb", data.length / 1024);
            });
        });
    }];
    
    [self test];
}

- (void)test{
    Personal *obj1 = [Personal new];
    obj1.age = 10;
    
    Personal *obj2 = [Personal new];
    obj2.age = 10;
    
    Personal *obj3 = obj1;
    
    NSArray *arr = [NSArray arrayWithObject:obj1];
    NSUInteger a = obj1.hash;
    NSUInteger b = obj2.hash;
    NSUInteger c = obj3.hash;
    BOOL b1 = [arr containsObject:obj1];
    BOOL b2 = [arr containsObject:obj2];
    BOOL b3 = [arr containsObject:obj3];
    
    NSString *aStr = @"a";
    NSString *bStr = [[NSString alloc] initWithFormat:@"a"];
    
}

@end
