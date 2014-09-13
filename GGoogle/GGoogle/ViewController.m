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
    
    CVImageBufferRef *buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:buffer];
    UIImage *image = [[UIImage alloc] initWithCIImage:ciImage];
//    UIImageView *display = [[UIImageView alloc] initWithImage:image];
//    display.frame = CGRectMake(0,0,self.view.frame.size.width/2, self.view.frame.size.height);
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
