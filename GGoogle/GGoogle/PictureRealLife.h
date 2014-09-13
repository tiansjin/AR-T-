//
//  PictureRealLife.h
//  GGoogle
//
//  Created by Rohan Varma on 9/13/14.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PictureRealLife : NSObject {
    double longitude;
    double latitude;
    double orientation;
    NSData *image;
    NSString *url;
}

@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double orientation;
@property (nonatomic, copy) NSData *image;
@property (nonatomic, copy) NSString *url;

- (id)initPictureRealLife:(double)theOongitude latitude:(double)theLatitude orientation:(double)theOrientation image:(NSData *)theImage;

@end
