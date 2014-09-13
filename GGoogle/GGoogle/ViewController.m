//
//  ViewController.m
//  GGoogle
//
//  Created by Tian Jin on 13/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>

@interface ViewController ()

@property UIView *leftScreen;
@property UIView *rightScreen;
@property UIView *leftImage;
@property UIView *rightImage;
@property UIImage *imageBeingDrawn;
@property AVCaptureSession *session;
@property CLLocationManager *loc_manager;
@property CLLocation *location_data;
@property CLHeading *currHeading;

@end

@implementation ViewController
            
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.leftScreen = [[UIView alloc] init];
    self.leftScreen.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    self.leftImage = [[UIImageView alloc] init];
    [self.view addSubview:self.leftScreen];
    self.rightScreen.frame = CGRectMake(self.view.frame.size.width/2, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    self.rightImage = [[UIImageView alloc] init];
    [self.view addSubview:self.rightScreen];
    
    self.session = [[AVCaptureSession alloc] init];
    [self.session beginConfiguration];
    [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    [self.session addInput:input];

    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self
                              queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [self.session addOutput:output];
    
    [self.session commitConfiguration];
    [self.session startRunning];
}

-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *newImage = [UIImage imageWithCGImage:quartzImage];
    CFRelease(quartzImage);

    UIGraphicsBeginImageContext(CGSizeMake(self.view.frame.size.width/2, self.view.frame.size.height));
    [newImage drawInRect:CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    

    if (image){
        [self.leftImage removeFromSuperview];
        [self.rightImage removeFromSuperview];
        self.leftImage = [[UIImageView alloc] initWithImage:image];
        self.leftImage.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
        self.rightImage = [[UIImageView alloc] initWithImage:image];
        self.rightImage.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        [self.leftScreen addSubview:self.leftImage];
        [self.rightScreen addSubview:self.rightImage];
    }
    NSArray *nearImages = [self ] //get images
    CLLocationCoordinate2D currLocation = [self getCoordinates];
    
    for (UIImage *image in nearImages) {
        if (image.orientation)
    }

}

- (CLLocationCoordinate2D) getCoordinates {
    if (!self.location_data) {
        self.location_data = [[CLLocation alloc] init];
    }
    CLLocationCoordinate2D coordinates = self.location_data.coordinate;
    return coordinates;
}

- (void) startHeadingEvents {
    if (!self.loc_manager) {
        self.loc_manager = [[CLLocationManager alloc]init];
    }
    self.loc_manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
    if (self.loc_manager.headingAvailable) {
        [self.loc_manager startUpdatingHeading];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    self.currHeading = newHeading;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (double) getDistanceFromLoc: (double)currLat longitude:(double)currLong picLat:(double)picLat picLong:(double)picLong {
    return ((currLat - picLat) ** 2 + (currLong + picLong) ** 2.0) **
}


@end
