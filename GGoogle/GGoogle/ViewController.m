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
static const double defaultNormDist = 0.00002;
bool isDrawing = false;
GLKVector3 xAxis;
GLKVector3 zAxis;
bool firstVector = true;
bool secondVector = true;
bool lastVector = false;
int VECTORSCALE = 1000;

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
//    NSLog(@"%f, %f", self.currLocation.coordinate.latitude, self.currLocation.coordinate.longitude);
}

- (void) renderImagesNearBy {
//    NSArray *constraints = [self getDistanceAllowedFromLoc: self.currLocation];
//    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"(longitude > %f) AND (longitude < %f) AND (latitude > %f) AND (latitude < %f)",
//                                   constraints[0], constraints[2], constraints[3], constraints[1]];
//    NSArray *nearImages = [self fetchImages:queryPredicate]; //get images
//    for (Image *image in nearImages) {
//        double distanceToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude
//                                                 picLat:image.latitude.doubleValue picLong:image.longitude.doubleValue];
//    }
    CALayer *layer = [CALayer layer];
    UIImage *rectangle = [UIImage imageNamed:@"rectangle.png"];
    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    double distToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude picLat:39.952331 picLong:-75.190505];
    CGSize resizeDimensions = [self getDimensionToScale:distToImg imgWidth:rectangle.size.width imgHeight:rectangle.size.height];
    CABasicAnimation *resizeAnimation = [self createResizeAnimation:resizeDimensions];
    resizeAnimation.duration = 0;

    UIImageView *rectangleView = [[UIImageView alloc] initWithImage:rectangle];
    layer = rectangleView.layer;
//    [self resize:rectangleView to:resizeDimensions withDuration:0 andSnapBack:false];
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
    [self.leftImage.image drawAtPoint:CGPointZero];
//    [layer renderInContext:UIGraphicsGetCurrentContext()];
    float angle = -(270.0f - (self.currHeading.trueHeading + 100));
    [self rotateImage:rectangle rotationAngle: angle];
    [rectangle drawAtPoint:CGPointZero];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();

    self.leftImage =[[UIImageView alloc] initWithImage:image];
    [self.leftScreen addSubview:self.leftImage];
    self.rightImage = [[UIImageView alloc] initWithImage:image];
    [self.rightScreen addSubview:self.rightImage];
    UIGraphicsEndImageContext();
}

- (UIImage *)imageFromLayer:(CALayer *)layer{
//    UIGraphicsBeginImageContext([layer frame].size);
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *outputImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    return outputImage;
}

- (void)resize:(UIView*)view to:(CGSize)size withDuration:(int) duration andSnapBack:(BOOL) snapBack
{
    // Prepare the animation from the old size to the new size
    CGRect oldBounds = view.layer.bounds;
    CGRect newBounds = oldBounds;
    newBounds.size = size;
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"bounds"];
    // iOS
    animation.fromValue = [NSValue valueWithCGRect:oldBounds];
    animation.toValue = [NSValue valueWithCGRect:newBounds];
    if(!snapBack) {
        // Update the layer’s bounds so the layer doesn’t snap back when the animation completes.
        view.layer.bounds = newBounds;
    }
    // Add the animation, overriding the implicit animation.
    [view.layer addAnimation:animation forKey:@"bounds"];
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
//    NSLog(@"%f, %f", ratio, distanceToImg);
//    NSLog(@"%f, %f", width * ratio, height * ratio);
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
//    NSLog(@"------");
//    NSLog(@"%f", (currLat - picLat));
//    NSLog(@"%f", (currLong + picLong));
    return sqrt(pow((currLat - picLat), 2) + pow((currLong - picLong), 2.0));
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
            lastVector = true;
            NSLog(@"we stopped drawing");
        } else {
            NSLog(@"ignored pose change since we weren't drawing");
        }
        
    }
}

- (void)didReceiveOrientationEvent:(NSNotification*)notification {
    // if not drawing and not last one, throw notification away
    if (!isDrawing && !lastVector) {
        return;
    }
    
    // extract vector from orientation
    TLMOrientationEvent *orientation = notification.userInfo[kTLMKeyOrientationEvent];
    GLKQuaternion quaternion = orientation.quaternion;
    GLKVector3 currentVec = GLKQuaternionAxis(quaternion);
    
    // if calibrating, get zaxis vector and send origin
    if (isDrawing && firstVector) {
        firstVector = false;
        zAxis = currentVec;
        [self renderCurrentLine:CGPointZero withBool:true];
        return;
    }
    
    // extract vector in xy plane by orthogonal projection
    GLKVector3 xyVector = GLKVector3Subtract(currentVec, GLKVector3Project(currentVec, zAxis));
    
    // HACK: if it's the second vector, pretend that it's the xaxis
    if (isDrawing && secondVector) {
        secondVector = false;
        xAxis = xyVector;
        CGFloat magn = GLKVector3Length(xyVector);
        [self renderCurrentLine:CGPointMake((CGFloat)(VECTORSCALE*magn), (CGFloat)0) withBool:true];
        return;
    }
    
    // hackily extract components in pretend xy plane by projecting onto pretend xaxis
    GLKVector3 xComp = GLKVector3Project(xyVector, xAxis);
    CGFloat xmagn = GLKVector3Length(xComp);
    GLKVector3 yComp = GLKVector3Subtract(xyVector, xComp);
    CGFloat ymagn = GLKVector3Length(yComp);
    if (lastVector) {
        lastVector = false;
        NSLog(@"SAVING IMAGE");
        [self renderCurrentLine:CGPointMake((VECTORSCALE*xmagn), (VECTORSCALE*ymagn)) withBool:false];
        firstVector = true;
        secondVector = true;
        return;
    }
    [self renderCurrentLine:CGPointMake((VECTORSCALE*xmagn), (VECTORSCALE*ymagn)) withBool:true];
    return;
}


@end
