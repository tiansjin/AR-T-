//
//  PictureRealLife.m
//  GGoogle
//
//  Created by Rohan Varma on 9/13/14.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import "PictureRealLife.h"

@implementation PictureRealLife

@synthesize latitude;
@synthesize longitude;
@synthesize orientation;
@synthesize image;

- (id)initPictureRealLife: (double)theLongitude latitude:(double)theLatitude
              orientation:(double)theOrientation image:(NSData *)theImage url:(NSString *) theUrl{
    if ((self = [super init])) {
        self.longitude = theLongitude;
        self.latitude = theLatitude;
        self.orientation = theOrientation;
        self.image = theImage;
        self.url = theUrl;
    }
    return self;
}

@end
