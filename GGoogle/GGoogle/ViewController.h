//
//  ViewController.h
//  GGoogle
//
//  Created by Tian Jin on 13/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreLocation/CoreLocation.h>
#import <MyoKit/MyoKit.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *loc_manager;


@end

