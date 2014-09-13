//
//  ViewController.swift
//  GGoggle
//
//  Created by Tian Jin on 12/09/2014.
//  Copyright (c) 2014 AART. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var leftScreen : UIView = UIView()
    var rightScreen : UIView = UIView ()
    var leftOverlay : CALayer = CALayer ()
    var rightOverlay : CALayer = CALayer ()
                            
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        leftScreen.frame = CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height)
        leftOverlay.frame = leftScreen.frame
        var left : AVCaptureSession = AVCaptureSession()
//        left.sessionPreset = AVCaptureSessionPresetPhoto
//        var leftFeed : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: left)
//        leftFeed.videoGravity = AVLayerVideoGravityResizeAspectFill
//        leftFeed.frame = leftScreen.frame
//        leftScreen.layer.addSublayer(leftFeed)
        leftScreen.layer.addSublayer(leftOverlay)
        var device : AVCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        var input : AVCaptureDeviceInput = AVCaptureDeviceInput.deviceInputWithDevice(device, error: nil) as AVCaptureDeviceInput
        left.addInput(input)
        
        var output : AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DISPATCH_QUEUE_SERIAL)
        left.addOutput(output)
        
//        left.startRunning()
        self.view.addSubview(leftScreen)
        
        rightScreen.frame = CGRectMake(self.view.frame.size.width/2, 0, self.view.frame.size.width/2, self.view.frame.size.height)
        print(self.view.frame)
        rightOverlay.frame = rightScreen.frame
        var right : AVCaptureSession = AVCaptureSession()
        right.sessionPreset = AVCaptureSessionPresetPhoto
//        var rightFeed : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: right)
//        rightFeed.videoGravity = AVLayerVideoGravityResizeAspectFill
//        rightFeed.frame = rightScreen.frame
//        rightScreen.layer.addSublayer(leftFeed)
        rightScreen.layer.addSublayer(rightOverlay)
//        device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
//        input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: nil) as AVCaptureDeviceInput
//        right.addInput(input)
        right.startRunning()
        self.view.addSubview(rightScreen)
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let ref  = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(CVImageBuffer: ref)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

