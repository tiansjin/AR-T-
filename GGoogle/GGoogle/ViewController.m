//
//  ViewController.m
//  GGoogle
//
//  Created by Tian Jin on 13/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import "ViewController.h"
#import "Image.h"
#import "AppDelegate.h"
#import <GLKit/GLKMath.h>

@interface ViewController ()

@property (nonatomic, strong) UIView *leftScreen;
@property (nonatomic, strong) UIView *rightScreen;
@property (nonatomic, strong) UIImageView *leftImage;
@property (nonatomic, strong) UIImageView *rightImage;
@property (nonatomic, strong) UIImage *imageBeingDrawn;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) CLLocation *currLocation;
@property (nonatomic, strong) CLHeading *currHeading;

@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;

@property (nonatomic, strong) UIBezierPath *currentLine;

@end

@implementation ViewController

static const double allowedDist = 0.1;
static const double defaultNormDist = 0.05;
bool isDrawing = false;

// new vars, fix comments later
TLMArmXDirection armXDirection;
bool isLastVector = false;
float initialYaw = -6; // min is -pi, so this marks it as unintialized
const int XSCALE = 500;
const int YSCALE = 500;

- (void)viewDidLoad {
    [super viewDidLoad];
     // Do any additional setup after loading the view, typically from a nib.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didConnectDevice:)
                                                 name:TLMHubDidConnectDeviceNotification
                                               object:nil];
    
    // Posted whenever the user does a Sync Gesture, and the Myo is calibrated
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didRecognizeArm:)
                                                 name:TLMMyoDidReceiveArmRecognizedEventNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceivePoseChange:)
                                                 name:TLMMyoDidReceivePoseChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveOrientationEvent:)
                                                 name:TLMMyoDidReceiveOrientationEventNotification
                                               object:nil];
    
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
//    [self renderCurrentLine:CGPointMake(0, 0) withBool:TRUE];
//    [self renderCurrentLine:CGPointMake(40, 0) withBool:TRUE];
//    [self renderCurrentLine:CGPointMake(40, 40) withBool:TRUE];
//    [self renderCurrentLine:CGPointMake(0, 40) withBool:FALSE];

    [[TLMHub sharedHub] attachToAny];
    
    self.loc_manager = [[CLLocationManager alloc] init];
    self.loc_manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    self.loc_manager.delegate = self;
//    [self.loc_manager requestAlwaysAuthorization];
    self.loc_manager.distanceFilter = kCLDistanceFilterNone;
    [self.loc_manager startUpdatingLocation];
    [self.loc_manager startUpdatingHeading];
    
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"status changed");
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
        CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
        [image drawAtPoint:CGPointZero];
        if (self.currentLine){
            CGContextRef context = UIGraphicsGetCurrentContext();
            [self.currentLine setLineWidth:2.0];
            [self.currentLine setLineJoinStyle:kCGLineJoinBevel];
            [[UIColor redColor] setStroke];
            [self.currentLine stroke];
            CGContextAddPath(context,self.currentLine.CGPath);
            UIImage *image2 = UIGraphicsGetImageFromCurrentImageContext();
            self.leftImage = [[UIImageView alloc] initWithImage:image2];
            self.leftImage.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
            self.rightImage = [[UIImageView alloc] initWithImage:image2];
            self.rightImage.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        } else {
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            self.leftImage = [[UIImageView alloc] initWithImage:image];
            self.leftImage.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
            self.rightImage = [[UIImageView alloc] initWithImage:image];
            self.rightImage.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        }
        if (false){
            [self renderImagesNearBy];
        } else {
            [self.leftScreen addSubview:self.leftImage];
            [self.rightScreen addSubview:self.rightImage];
        }
    }
}

- (void) renderImagesNearBy {
    NSArray *constraints = [self getDistanceAllowedFromLoc: self.currLocation];
    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"(longitude > %f) AND (longitude < %f) AND (latitude > %f) AND (latitude < %f)",
                                   constraints[0], constraints[2], constraints[3], constraints[1]];
    NSArray *nearImages = [self fetchImages:queryPredicate]; //get images
//    for (Image *image in nearImages) {
//        double distanceToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude
//                                                 picLat:image.latitude.doubleValue picLong:image.longitude.doubleValue];
//    }
    UIImage *rectangle = [UIImage imageNamed:@"rectangle.png"];
    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
//    double distToImg = [self getDistanceFromLoc:this.currLocation.coordinate.latitude longitude:this.currLocation.coordinate.latitude picLat:<#(double)#> picLong:<#(double)#>
    [self.leftImage.image drawAtPoint:CGPointZero];
//    CGPoint rectangleAnchor;
//    rectangleAnchor.x = 270 - (self.currHeading.trueHeading + 100) + (self.view.frame.size.width/4 - rect.size.width/2);
//    NSLog(@"%f", 270 - (self.currHeading.trueHeading + 100) + (self.view.frame.size.width/4 - rect.size.width/2));
//    rectangleAnchor.y = self.view.frame.size.height/2 - rect.size.height/2;
    float angle = -(270.0f - (self.currHeading.trueHeading + 100));
    NSLog(@"%f", angle);
    [self rotateImage:rectangle rotationAngle: angle];
    [rectangle drawAtPoint:CGPointZero];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    self.leftImage =[[UIImageView alloc] initWithImage:image];
    [self.leftScreen addSubview:self.leftImage];
    self.rightImage = [[UIImageView alloc] initWithImage:image];
    [self.rightScreen addSubview:self.rightImage];
    UIGraphicsEndImageContext();
}

- (CABasicAnimation *) createResizeAnimation:(CGSize)newDimensions {
    CABasicAnimation *resizeAnimation = [CABasicAnimation animationWithKeyPath:@"bounds.size"];
    [resizeAnimation setToValue:[NSValue valueWithCGSize:newDimensions]];
    resizeAnimation.fillMode = kCAFillModeForwards;
    resizeAnimation.removedOnCompletion = NO;
    return resizeAnimation;
}

- (CGSize) getDimensionToScale:(double)distanceToImg imgWidth:(double)width imgHeight:(double)height {
    double ratio = defaultNormDist / (distanceToImg);
    return CGSizeMake(width * ratio, height * ratio);
}

- (void) locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations{
    CLLocation *loc = locations[0];
    self.currLocation = locations[0];
//    NSLog(@"%f,%f", loc.coordinate.latitude, loc.coordinate.longitude);
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
    if (drawing){
        if (!self.currentLine){
            self.currentLine = [UIBezierPath bezierPath];
            [self.currentLine moveToPoint:CGPointMake(rect.size.width/2, rect.size.height/2)];
        } else {
            [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                         coordinate.y + rect.size.height/2)];
        }
    } else {
        UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                     coordinate.y + rect.size.height/2)];
        [self.currentLine setLineWidth:3.0];
        [self.currentLine setLineJoinStyle:kCGLineJoinBevel];
        [[UIColor redColor] setStroke];
        [self.currentLine stroke];
        CGContextAddPath(context,self.currentLine.CGPath);
        [[UIColor redColor] setStroke];
        UIImage *saveImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        self.currentLine = nil;
        CLLocationCoordinate2D loc = self.currLocation.coordinate;
        [self saveImage:saveImage withLong:loc.longitude withLat:loc.latitude withOrient:self.currHeading.trueHeading];
    }
    
}

/* Takes an UIImage, rotates it, and returns the transposed version of the image */
- (UIImage*)rotateImage:(UIImage*)img rotationAngle:(float)z  {
    
    //Create the container
    CALayer *container = [CALayer layer];
    container.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    [self.view.layer addSublayer:container];
    
    //Create a Plane
    CALayer *imagePlane =
    [self addPlaneToLayer:container
                    image: img
                     size:CGSizeMake(self.view.frame.size.width/2, self.view.frame.size.height/2)
                 position:CGPointMake(0, 0)
                    color:[UIColor clearColor]];
    
    // Apply the transform to the PLANE
    CATransform3D t = CATransform3DIdentity;
    
    // Perform the rotation around the z axis
    t = CATransform3DRotate(t, z * M_PI / 180.0f, 0, 1, 0);
    imagePlane.transform = t;
    
    //Convert container back to image
    UIImage* containedImage = [self imageFromLayer:container];
    
    return containedImage;
}

- (CALayer*)addPlaneToLayer:(CALayer*)container image:(UIImage*)img size:(CGSize)size position:(CGPoint)point color:(UIColor*)color{
    //Initialize the layer
    CALayer *plane = [CALayer layer];
    plane.contents = (id)img.CGImage; // Add image to the plane
    plane.backgroundColor = [color CGColor];
    plane.frame = CGRectMake(point.x, point.y, size.width, size.height);
    //Add the layer to the container layer
    [container addSublayer:plane];
    
    return plane;
}

- (UIImage *)imageFromLayer:(CALayer *)layer
{
    UIGraphicsBeginImageContext([layer frame].size);
    
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return outputImage;
}

//- (void)addCurrentLine{
//    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
//    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
//    [self.leftImage.image drawAtPoint:CGPointZero];
//    CGContextRef context = UIGraphicsGetCurrentContext();
//    [[UIColor redColor] setStroke];
//    [self.currentLine stroke];
//    CGContextAddPath(context,self.currentLine.CGPath);
//    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//    self.leftImage =[[UIImageView alloc] initWithImage:image];
//    [self.leftScreen addSubview:self.leftImage];
//    self.rightImage = [[UIImageView alloc] initWithImage:image];
//    [self.rightScreen addSubview:self.rightImage];
//    //        UIGraphicsPopContext();
//    UIGraphicsEndImageContext();
//}

- (void)didConnectDevice:(NSNotification *)notification {
    NSLog(@"connected device");
}

- (void)didRecognizeArm:(NSNotification *)notification {
    // Retrieve the arm event from the notification's userInfo with the kTLMKeyArmRecognizedEvent key.
    TLMArmRecognizedEvent *armEvent = notification.userInfo[kTLMKeyArmRecognizedEvent];
    armXDirection = armEvent.xDirection;
    NSLog(@"recognized arm");
}

- (void)didReceivePoseChange:(NSNotification*)notification {
    TLMPose *pose = notification.userInfo[kTLMKeyPose];
    if (pose.type == TLMPoseTypeFist) {
        isDrawing = true;
        NSLog(@"we started drawing");
    }
    else {
        if (isDrawing) {
            isDrawing = false;
            isLastVector = true;
            NSLog(@"we stopped drawing");
        } else {
            NSLog(@"ignored pose change since we weren't drawing");
        }
    }
}

- (void)didReceiveOrientationEvent:(NSNotification*)notification {
    // if not drawing and not last one, throw notification away
    if (!isDrawing && !isLastVector) {
        return;
    }
    
    // extract pitch and yaw from quaternion
    TLMOrientationEvent *orientation = notification.userInfo[kTLMKeyOrientationEvent];
    GLKQuaternion quaternion = orientation.quaternion;
    float pitch = asin(2.0f * (quaternion.q[3] * quaternion.q[1] - quaternion.q[2] * quaternion.q[0]));
    float yaw = atan2(2.0f * (quaternion.q[3] * quaternion.q[2] + quaternion.q[0] * quaternion.q[1]),
                      1.0f - 2.0f * (quaternion.q[1] * quaternion.q[1] + quaternion.q[2] * quaternion.q[2]));
    
    // get y value
    NSLog(@"sample pitch value: %f", pitch);
    float ymag = YSCALE*tan(pitch);
    if (armXDirection == TLMArmXDirectionTowardElbow) {
        pitch *= -1; // might not be necessary, suspect this for bugs
    }
    
    // get x value
    NSLog(@"sample yaw value: %f", yaw);
    if (initialYaw < -5) { // check for invalidity
        initialYaw = yaw;
        [self renderCurrentLine:CGPointMake((CGFloat)0, (CGFloat)ymag) withBool:YES];
        return;
    }
    float angle1 = fabsf(yaw - initialYaw);
    float angle2 = fabsf(initialYaw - yaw);
    float xmag;
    if (angle1 < (M_PI/2) && angle1 < angle2) {
        xmag = XSCALE*tan(yaw - initialYaw);
    } else if (angle2 < (M_PI/2) && angle2 < angle1) {
        xmag = XSCALE*tan(initialYaw - yaw);
    } else {
        return; // outside our 180 degree arc, who cares?
    }
    
    // check for special case of last vector
    if (isLastVector) {
        // reset values
        isLastVector = NO;
        initialYaw = -6; // again, just to be invalid HACK HACK HACK
        [self renderCurrentLine:CGPointMake((CGFloat)xmag, (CGFloat)ymag) withBool:NO];
    } else {
        [self renderCurrentLine:CGPointMake((CGFloat)xmag, (CGFloat)ymag) withBool:YES];
    }
    return;
}

@end
