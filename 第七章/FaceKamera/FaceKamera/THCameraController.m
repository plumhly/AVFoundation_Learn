//
//  MIT License
//
//  Copyright (c) 2014 Bob McCune http://bobmccune.com/
//  Copyright (c) 2014 TapHarmonic, LLC http://tapharmonic.com/
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "THCameraController.h"
#import <AVFoundation/AVFoundation.h>

@interface THCameraController ()<AVCaptureMetadataOutputObjectsDelegate> // Listing 7.7

// Listing 7.6
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;

@end

@implementation THCameraController

- (BOOL)setupSessionOutputs:(NSError **)error {

    // Listing 7.6
    _metadataOutput = [AVCaptureMetadataOutput new];
    if ([self.captureSession canAddOutput:_metadataOutput]) {
        [self.captureSession addOutput:_metadataOutput];
        _metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
        [_metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        return YES;
    } else {
        NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"fail to still image output"};
        *error = [NSError errorWithDomain:THCameraErrorDomain code:THCameraErrorFailedToAddOutput userInfo:userInfo];
    }
    return NO;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
       fromConnection:(AVCaptureConnection *)connection {

    // Listing 7.7
    for (AVMetadataFaceObject *object in metadataObjects) {
        NSLog(@"face id: %li", object.faceID);
        NSLog(@"bunds: %@", NSStringFromCGRect(object.bounds));
    }

    [self.faceDetectionDelegate didDetectFaces:metadataObjects];

}

@end

