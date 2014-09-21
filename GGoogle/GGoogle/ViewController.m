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
@property int count;

@property (nonatomic, strong) NSMutableArray *imageArray;
@property (nonatomic, strong) NSMutableArray *layerArray;

@property (nonatomic, strong) Image *minionImg;


@end

@implementation ViewController

static const double allowedDist = 0.1;
static const double defaultNormDist = 0.00002;
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
    [self.loc_manager requestAlwaysAuthorization];
    self.loc_manager.distanceFilter = kCLDistanceFilterNone;
    [self.loc_manager startUpdatingLocation];
    [self.loc_manager startUpdatingHeading];
    
    self.minionImg = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                   inManagedObjectContext:self.managedObjectContext];;
    self.minionImg.image = UIImagePNGRepresentation([UIImage imageNamed:@"minion.png"]);
    self.minionImg.orientation = [NSNumber numberWithDouble: 120.0];
    self.minionImg.latitude = [NSNumber numberWithDouble: 0.0];
    self.minionImg.latitude = [NSNumber numberWithDouble: 0.0];
    
//    self.imageArray = [[NSMutableArray alloc] initWithArray:@[[UIImage imageNamed:@"testing.png"], [UIImage imageNamed:@"minion.png"]]];
//    self.layerArray = [[NSMutableArray alloc] initWithArray:@[[[CALayer alloc] init], [[CALayer alloc] init], [[CALayer alloc] init], [[CALayer alloc] init]]];
    [self setupImagesNearby];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"status changed");
}

-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    [self renderImagesNearBy];
    
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
            UIGraphicsEndImageContext();
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
        } else {
            [self.leftScreen addSubview:self.leftImage];
            [self.rightScreen addSubview:self.rightImage];
        }
    }
//    NSLog(@"%f, %f", self.currLocation.coordinate.latitude, self.currLocation.coordinate.longitude);
}

- (void) setupImagesNearby{
    
    NSEntityDescription *entityDescription = [NSEntityDescription
                                              entityForName:@"Image" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDescription];
    
    
//    NSArray *constraints = [self getDistanceAllowedFromLoc: self.currLocation];
//    NSPredicate *queryPredicate = [NSPredicate predicateWithFormat:@"(longitude > %f) AND (longitude < %f) AND (latitude > %f) AND (latitude < %f)",
//                                   constraints[0], constraints[2], constraints[3], constraints[1]];
    self.imageArray =[self.managedObjectContext executeFetchRequest:request error:nil];
//    [self fetchImages:queryPredicate]; //get images
//    [self.imageArray addObject:self.minionImg];
    self.layerArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < [self.imageArray count]; i ++){
        [self.layerArray addObject:[CALayer layer]];
        [self.layerArray addObject:[CALayer layer]];
    }
    
}

- (void) renderImagesNearBy {

    int i = 0;
    for (Image *data in self.imageArray) {
        UIImage *image = [UIImage imageWithData:data.image];
        CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
        //UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
        CGPoint rectangleAnchor;
        if (-30 < data.orientation.doubleValue - (self.currHeading.trueHeading) < 30) {
            rectangleAnchor.x = (((data.orientation.doubleValue - (self.currHeading.trueHeading)) + 30) / 60) * self.view.frame.size.width/2;
        } else {
            rectangleAnchor.x = -500;
        }
//        if (rectangleAnchor.x > (0 - image.size.width) && rectangleAnchor.x < (self.leftScreen.frame.size.width + image.size.width)) {
        if (-100 < rectangleAnchor.x && rectangleAnchor.x < 160) {
            rectangleAnchor.y = self.view.frame.size.height/2 - image.size.height/2;
            float angle = -(180 - (self.currHeading.trueHeading));
            [self rotateImage:image rotationAngle: angle placeAt:rectangleAnchor atIndex:i];
        } else {
            [self.layerArray[i] removeFromSuperlayer];
            [self.layerArray[i+1] removeFromSuperlayer];
        }
        i += 2;
    }

    
//    for (Image *image in nearImages) {
//        double distanceToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude
//                                                 picLat:image.latitude.doubleValue picLong:image.longitude.doubleValue];
//    }
//    CALayer *layer = [CALayer layer];

//    UIImage *rectangle = [UIImage imageNamed:@"testing.png"];
//    int i = 0;
//    int degree_count = 0;
//    for (UIImage *image in self.imageArray) {
//        CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
//        //UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0);
//        CGPoint rectangleAnchor;
//        if (-20 < 180 * degree_count - (self.currHeading.trueHeading + 100) < 20) {
//            rectangleAnchor.x = (((180 * degree_count - (self.currHeading.trueHeading + 100)) + 20) / 40) * self.view.frame.size.width/2;
//        } else {
//            rectangleAnchor.x = -500;
//        }
//        rectangleAnchor.y = self.view.frame.size.height/2 - image.size.height/2;
//        float angle = -(180*degree_count - (self.currHeading.trueHeading + 100));
//        [self rotateImage:image rotationAngle: angle placeAt:rectangleAnchor atIndex:i];
//        i += 2;
//        degree_count += 1;
//    }
    
//    double distToImg = [self getDistanceFromLoc:self.currLocation.coordinate.latitude longitude:self.currLocation.coordinate.longitude picLat:39.952331 picLong:-75.190505];
//    CGSize resizeDimensions = [self getDimensionToScale:distToImg imgWidth:rectangle.size.width imgHeight:rectangle.size.height];
//    CABasicAnimation *resizeAnimation = [self createResizeAnimation:resizeDimensions];
//    resizeAnimation.duration = 0;

//    UIImageView *rectangleView = [[UIImageView alloc] initWithImage:rectangle];
//    layer = rectangleView.layer;
//    [self resize:rectangleView to:resizeDimensions withDuration:0 andSnapBack:false];
    
//    [self.leftImage.image drawAtPoint:CGPointZero];
//    [rectangle drawAtPoint:CGPointZero];
//    [layer renderInContext:UIGraphicsGetCurrentContext()];
    
//    rectangleAnchor.x = 270 - (self.currHeading.trueHeading + 100) + (self.view.frame.size.width/4 - rect.size.width/2);
//    NSLog(@"%f", 270 - (self.currHeading.trueHeading + 100) + (self.view.frame.size.width/4 - rect.size.width/2));
    
//    [rectangle drawAtPoint:CGPointZero];
//    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();

//    self.leftImage =[[UIImageView alloc] initWithImage:image];
//    [self.leftScreen addSubview:self.leftImage];
//    self.rightImage = [[UIImageView alloc] initWithImage:image];
//    [self.rightScreen addSubview:self.rightImage];
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
    return sqrt(pow((currLat - picLat), 2) + pow((currLong - picLong), 2.0));
}

#pragma mark - Rendering Current Drawing
- (void) renderCurrentLine:(CGPoint) coordinate withBool:(BOOL) drawing{
    // Andrew, Ashley, call this function when you want to update the screen image
    CGRect rect = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    if (drawing){
        if (!self.currentLine){
            self.count = 0;
            self.currentLine = [UIBezierPath bezierPath];
            [self.currentLine moveToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                                  coordinate.y + rect.size.height/2)];
        } else {
            self.count++;
            [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,coordinate.y + rect.size.height/2)];
        }
    } else {
        if (self.count > 5){
            CGContextRef context = UIGraphicsGetCurrentContext();
    //        UIGraphicsPushContext(context);
            UIGraphicsBeginImageContext(rect.size); //now it's here.
            [self.currentLine addLineToPoint:CGPointMake(coordinate.x + rect.size.width/2,
                                                         coordinate.y + rect.size.height/2)];
            [self.currentLine setLineWidth:3.0];
            [self.currentLine setLineJoinStyle:kCGLineJoinBevel];
            [[UIColor redColor] setStroke];
            [self.currentLine stroke];
            CGContextAddPath(context, self.currentLine.CGPath);
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    //        UIGraphicsPopContext();
            UIGraphicsEndImageContext();
            
            
        
            CLLocationCoordinate2D loc = self.currLocation.coordinate;
            [self saveImage:image withLong:loc.longitude withLat:loc.latitude withOrient:self.currHeading.trueHeading];
            [self setupImagesNearby];
        }
        self.currentLine = nil;
        self.count = 0;
    }
    
}

/* Takes an UIImage, rotates it, and returns the transposed version of the image */
- (void)rotateImage:(UIImage*)img rotationAngle:(float)z placeAt:(CGPoint)position atIndex:(int)imgIndex {
    //Create the container
    if (self.layerArray[imgIndex]){
        [self.layerArray[imgIndex]removeFromSuperlayer];
        [self.layerArray[imgIndex] setContents:nil];
    }
    if (self.layerArray[imgIndex+1]) {
        [self.layerArray[imgIndex+1]removeFromSuperlayer];
        [self.layerArray[imgIndex+1] setContents:nil];
    }
    CALayer *container = [[CALayer alloc] init];
    CALayer *container2 = [[CALayer alloc] init];
    container.bounds = CGRectMake(0, 0, img.size.width, img.size.height);
    container2.bounds = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
//    layer = container;
//    layer2 = container2;
    container.frame = CGRectMake(0, 0, img.size.width, img.size.height);
    container2.frame = CGRectMake(self.view.frame.size.width/2, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    
    //Create a Plane
    CALayer *imagePlane =
    [self addPlaneToLayer:container
                    image: img
                     size:img.size
                 position:position
                    color:[UIColor clearColor]];
    
    //Create a Plane
    CALayer *imagePlane2 =
    [self addPlaneToLayer:container2
                    image: img
                     size:img.size
                 position:position
                    color:[UIColor clearColor]];
    
    // Apply the transform to the PLANE
    CATransform3D t = CATransform3DIdentity;
    
    // Perform the rotation around the z axis
    t = CATransform3DRotate(t, z * M_PI / 180.0f, 0, 1, 0);
    imagePlane.transform = t;
    imagePlane2.transform = t;
    
    [self.layerArray replaceObjectAtIndex:imgIndex withObject:container];
    [self.layerArray replaceObjectAtIndex:imgIndex+1 withObject:container2];
    [self.view.layer addSublayer:container];
    [self.view.layer addSublayer:container2];
    
    //Convert container back to image
//    UIImage* containedImage = [self imageFromLayer:container];
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
    if (armXDirection == TLMArmXDirectionTowardElbow) {
        pitch *= -1; // might not be necessary, suspect this for bugs
    }
    double ymag = YSCALE*tan(pitch);
    
    // get x value
    if (initialYaw < -5) { // check for invalidity
        initialYaw = yaw;
        [self renderCurrentLine:CGPointMake((CGFloat)0, (CGFloat)ymag) withBool:true];
        return;
    }
    double delta = yaw - initialYaw;
    double xmag = -XSCALE*tan(delta);
    
    // check for special case of last vector
    if (isLastVector) {
        // reset values
        isLastVector = false;
        initialYaw = -6; // again, just to be invalid HACK HACK HACK
        [self renderCurrentLine:CGPointMake((CGFloat)(float)xmag, (CGFloat)(float)ymag) withBool:false];
    } else {
        [self renderCurrentLine:CGPointMake((CGFloat)(float)xmag, (CGFloat)(float)ymag) withBool:true];
    }
    return;
}

@end
