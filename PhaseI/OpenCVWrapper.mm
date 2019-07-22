//
//  OpenCVWrapper.m
//  PhaseI
//
//  Created by Lara Riparip on 22.07.19.
//  Copyright © 2019 Lara Riparip. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import "OpenCVWrapper.h"


@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

@end
