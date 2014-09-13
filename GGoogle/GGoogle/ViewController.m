//
//  ViewController.m
//  GGoogle
//
//  Created by Tian Jin on 13/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property UIView *leftScreen;
@property UIView *rightScreen;
@property UIView *leftImage;
@property UIView *rightImage;
@property AVCaptureSession *session;

@end

@implementation ViewController
            
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.leftScreen = [[UIView alloc] init];
    self.leftScreen.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height);
    self.leftImage = [[UIImageView alloc] init];
    [self.view addSubview:self.leftScreen];
    self.rightScreen = [[UIView alloc] init];
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
                              queue:dispatch_queue_create("VideoSampleQueue", DISPATCH_QUEUE_PRIORITY_DEFAULT)];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [output setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    [self.session addOutput:output];
    
    [self.session commitConfiguration];
    [self.session startRunning];
}

//-(void) captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
//
//    CVImageBufferRef *buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
//    UIImage *image = [[UIImage alloc] initWithCIImage:ciImage];
//    UIImageView *display = [[UIImageView alloc] initWithImage:image];
//    display.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
//    [self.leftImage removeFromSuperview];
//    [self.rightImage removeFromSuperview];
//    self.leftImage = display;
//    self.rightImage = display;
//    [self.leftScreen addSubview:self.leftImage];
//    [self.rightScreen addSubview:self.rightImage];
//}

-(void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
//    CVImageBufferRef *buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
//    UIImage *image = [[UIImage alloc] initWithCIImage:ciImage];
//    UIImageView *display = [[UIImageView alloc] initWithImage:image];
//    display.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
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
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
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

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
