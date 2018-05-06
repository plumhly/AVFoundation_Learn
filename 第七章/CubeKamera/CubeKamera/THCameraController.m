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
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface THCameraController () <AVCaptureVideoDataOutputSampleBufferDelegate>

// Listing 7.28
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) AVCaptureVideoDataOutput *dataOutput;

// Listing 7.29
@property (nonatomic) CVOpenGLESTextureCacheRef textureCache;
@property (nonatomic) CVOpenGLESTextureRef texture;

@end

@implementation THCameraController

- (instancetype)initWithContext:(EAGLContext *)context {
    self = [super init];
    if (self) {

        // Listing 7.28
        _context = context;
        
        // Listing 7.29
        CVReturn number = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_textureCache);
        if (number != kCVReturnSuccess) {
            NSLog(@"create texture cache failed: %d", number);
        }
    }
    return self;
}

- (NSString *)sessionPreset {
    return AVCaptureSessionPreset640x480;
}

- (BOOL)setupSessionOutputs:(NSError **)error {
    
    // Listing 7.28
    _dataOutput = [[AVCaptureVideoDataOutput alloc] init];
    _dataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    [_dataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    if ([self.captureSession canAddOutput:_dataOutput]) {
        [self.captureSession addOutput:_dataOutput];
        return YES;
    }

    return NO;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {

    // Listing 7.30
    CVImageBufferRef sourceImage = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(formatDescription);
    CVReturn err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textureCache, sourceImage, NULL, GL_TEXTURE_2D, GL_RGBA, dimension.height, dimension.height, GL_BGRA, GL_UNSIGNED_BYTE, 0, &_texture);
    if (!err) {
        GLenum target = CVOpenGLESTextureGetTarget(_texture);
        GLint name = CVOpenGLESTextureGetName(_texture);
        [self.textureDelegate textureCreatedWithTarget:target name:name];
    } else {
        NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage error: %d", err);
    }
    [self cleanupTextures];
}

- (void)cleanupTextures {

    // Listing 7.30
    if (_texture) {
        CFRelease(_texture);
        _texture = NULL;
    }
    CVOpenGLESTextureCacheFlush(_textureCache, 0);
}

@end

