//
//  ViewController.m
//  GGoogle
//
//  Created by Tian Jin on 13/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import "Image.h"
#import "AppDelegate.h"

@interface ViewController ()

@property UIView *leftScreen;
@property UIView *rightScreen;
@property UIImageView *leftImage;
@property UIImageView *rightImage;
@property UIImage *imageBeingDrawn;
@property AVCaptureSession *session;
@property CLLocationManager *loc_manager;
@property CLLocation *currLocation;
@property CLHeading *currHeading;

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, strong) UIBezierPath *currentLine;

@end

@implementation ViewController

static const double allowedDist = 0.03;
            
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.leftScreen = [[UIView alloc] init];
    self.leftScreen.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    self.leftImage = [[UIImageView alloc] init];
    [self.view addSubview:self.leftScreen];
    self.rightScreen = [[UIImageView alloc] init];
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
    
    AppDelegate *AD = [UIApplication sharedApplication].delegate;
    self.managedObjectContext = AD.managedObjectContext;
    
    // ** TESTING RENDER CURRENT IMAGE **//
    [self renderCurrentLine:CGPointMake(0, 0) withBool:TRUE];
    [self renderCurrentLine:CGPointMake(40, 0) withBool:TRUE];
    [self renderCurrentLine:CGPointMake(40, 40) withBool:TRUE];
    [self renderCurrentLine:CGPointMake(0, 40) withBool:FALSE];
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
    
    // IF YOU WANT TO CHANGE ZOOM, CHANGE THIS RATIO
    double ratio = self.leftImage.frame.size.width/(newImage.size.width/6);
    UIImage *image = [UIImage imageWithCGImage:newImage.CGImage scale:ratio orientation:UIImageOrientationUp];

    if (image){
        [self.leftImage removeFromSuperview];
        [self.rightImage removeFromSuperview];
        self.leftImage = [[UIImageView alloc] initWithImage:image];
        self.leftImage.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
        self.rightImage = [[UIImageView alloc] initWithImage:image];
        self.rightImage.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        if (self.currentLine){
            [self addCurrentLine];
        } else {
            [self.leftScreen addSubview:self.leftImage];
            [self.rightScreen addSubview:self.rightImage];
        }
    }
    NSLog(@"%f, %f ", self.currLocation.coordinate.longitude, self.currLocation.coordinate.latitude);
//    NSLog(@"%f", self.currHeading.trueHeading);
//    NSArray *constraints = [self getDistanceAllowedFromLoc: self.currLocation];
//    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"(longitude > %f) AND (longitude < %f) AND (latitude > %f) AND (latitude < %f)",
//                                   constraints[0], constraints[2], constraints[3], constraints[1]];
//    NSArray *nearImages = [self fetchImages:queryPredicate]; //get images
//    for (Image *image in nearImages) {
//        double distanceToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude
//                                                  picLat:image.latitude.doubleValue picLong:image.longitude.doubleValue];
//        if (image.orientation )
//    };
    
    
//    NSArray *nearImages = [self ] //get images
//    CLLocationCoordinate2D currLocation = [self getCoordinates];
//    
//    for (UIImage *image in nearImages) {
//        if (image.orientation)
//    }

}

- (void) getCoordinates {
    if (!self.loc_manager) {
        self.loc_manager = [[CLLocationManager alloc] init];
    }
    self.loc_manager.desiredAccuracy = kCLLocationAccuracyBest;
    self.loc_manager.delegate = self;
    [self.loc_manager startUpdatingLocation];
}

-(void)locationManager:(CLLocationManager *)manager
   didUpdateToLocation:(CLLocation *)newLocation
          fromLocation:(CLLocation *)oldLocation {
    self.currLocation = newLocation;
}

- (void) startHeadingEvents {
    if (!self.loc_manager) {
        self.loc_manager = [[CLLocationManager alloc] init];
    }
    self.loc_manager.desiredAccuracy = kCLLocationAccuracyBest;
    if (self.loc_manager.headingAvailable) {
        [self.loc_manager startUpdatingHeading];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    self.currHeading = newHeading;
}

- (NSArray *) getDistanceAllowedFromLoc: (CLLocation *)currLocation {
    double lat = currLocation.coordinate.latitude;
    double lon = currLocation.coordinate.longitude;
    double bottom = lat - allowedDist;
    double left = lon - allowedDist;
    double top = lat + allowedDist;
    double right = lon + allowedDist;
    NSArray *constraints = @[@(left), @(top), @(right), @(bottom)];
    return constraints;
}

- (BOOL) saveImage:(UIImage *)image
          withLong:(double)longi
           withLat:(double)lat
        withOrient:(double)orient{
    Image *newImage = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                    inManagedObjectContext:self.managedObjectContext];
    newImage.image = UIImagePNGRepresentation(image);
    newImage.longitude = [NSNumber numberWithDouble:longi];
    newImage.latitude = [NSNumber numberWithDouble:lat];
    newImage.orientation = [NSNumber numberWithDouble:orient];
    NSError *error;
    if (![self.managedObjectContext save:&error]) {
        NSLog(@"Whoops, couldn't save: %@", [error localizedDescription]);
        return FALSE;
    }
    return TRUE;
}

- (NSArray *) fetchImages:(NSPredicate *)predicate{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Image"
                                              inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];
    [request setPredicate:predicate];
    NSArray *fetchedRecords = [self.managedObjectContext executeFetchRequest:request error:nil];
    return fetchedRecords;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (double) getDistanceFromLoc: (double)currLat longitude:(double)currLong picLat:(double)picLat picLong:(double)picLong {
    return sqrt(pow((currLat - picLat), 2) + pow((currLong + picLong), 2.0));
}

#pragma mark - Rendering Current Drawing
- (void) renderCurrentLine:(CGPoint) coordinate withBool:(BOOL) drawing{
    // Andrew, Ashley, call this function when you want to update the screen image
    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
    [self.leftImage.image drawAtPoint:CGPointZero];
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (drawing){
        if (!self.currentLine){
            self.currentLine = [UIBezierPath bezierPath];
            [self.currentLine moveToPoint:CGPointMake(rect.size.width/2, rect.size.height/2)];
        } else {
            [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                         coordinate.y + rect.size.height/2)];
        }
        [self.currentLine setLineWidth:3.0];
        [self.currentLine setLineJoinStyle:kCGLineJoinBevel];
        [[UIColor redColor] setStroke];
        [self.currentLine stroke];
//        [self.currentLine fill];
        CGContextAddPath(context,self.currentLine.CGPath);
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        [self.leftImage removeFromSuperview];
        self.leftImage =[[UIImageView alloc] initWithImage:image];
        [self.leftScreen addSubview:self.leftImage];
        [self.rightImage removeFromSuperview];
        self.rightImage = [[UIImageView alloc] initWithImage:image];
        [self.rightScreen addSubview:self.rightImage];
        UIGraphicsEndImageContext();
    } else {
        [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                     coordinate.y + rect.size.height/2)];
        [self.currentLine setLineWidth:3.0];
        [self.currentLine setLineJoinStyle:kCGLineJoinBevel];
        [[UIColor redColor] setStroke];
        [self.currentLine stroke];
        CGContextAddPath(context,self.currentLine.CGPath);
        [[UIColor redColor] setStroke];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        [self.leftImage removeFromSuperview];
        self.leftImage =[[UIImageView alloc] initWithImage:image];
        [self.leftScreen addSubview:self.leftImage];
        [self.rightImage removeFromSuperview];
        self.rightImage = [[UIImageView alloc] initWithImage:image];
        [self.rightScreen addSubview:self.rightImage];
        UIGraphicsEndImageContext();
        
//        self.currentLine = nil;
        CLLocationCoordinate2D loc = self.currLocation.coordinate;
        [self saveImage:image withLong:loc.longitude withLat:loc.latitude withOrient:self.currHeading.trueHeading];
    }
    
}

- (void)addCurrentLine{
    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
    [self.leftImage.image drawAtPoint:CGPointZero];
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor redColor] setStroke];
    [self.currentLine stroke];
    CGContextAddPath(context,self.currentLine.CGPath);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    self.leftImage =[[UIImageView alloc] initWithImage:image];
    [self.leftScreen addSubview:self.leftImage];
    self.rightImage = [[UIImageView alloc] initWithImage:image];
    [self.rightScreen addSubview:self.rightImage];
    //        UIGraphicsPopContext();
    UIGraphicsEndImageContext();

}


@end
