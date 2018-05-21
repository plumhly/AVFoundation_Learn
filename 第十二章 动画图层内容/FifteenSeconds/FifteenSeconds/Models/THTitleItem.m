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

#import "THTitleItem.h"
#import "THConstants.h"

@interface THTitleItem ()
@property (copy, nonatomic) NSString *text;
@property (strong, nonatomic) UIImage *image;
@property (nonatomic) CGRect bounds;
@end

@implementation THTitleItem

+ (instancetype)titleItemWithText:(NSString *)text image:(UIImage *)image {
    return [[self alloc] initWithText:text image:image];
}

- (instancetype)initWithText:(NSString *)text image:(UIImage *)image {
    self = [super init];
    if (self) {

        // Listing 12.2
        _text = text;
        _image = image;
        _bounds = TH720pVideoRect;
    }
    return self;
}

- (CALayer *)buildLayer {

    // Listing 12.2
    CALayer *parentLayer = [CALayer layer];
    parentLayer.opacity = 0;
    parentLayer.frame = _bounds;
    
    CALayer *imageLayer = [self makeImageLayer];
    [parentLayer addSublayer:imageLayer];
    
    CALayer *textLayer = [self makeTextLayer];
    [parentLayer addSublayer:textLayer];
    // Listing 12.3
    CAAnimation *fadeInoutAnimation = [self makeFadeInFadeOutAnimation];
    [parentLayer addAnimation:fadeInoutAnimation forKey:nil];
    
    // Listing 12.4
    if (_animateImage) {
        parentLayer.sublayerTransform = THMakePerspectiveTransform(1000);
        CAAnimation *spinAnimation = [self make3DSpinAnimation];
        NSTimeInterval offset = spinAnimation.beginTime + spinAnimation.duration - 0.5;
        CAAnimation *popAnimation = [self makePopAnimationWithTimingOffset:offset];
        
        [imageLayer addAnimation:spinAnimation forKey:nil];
        [imageLayer addAnimation:popAnimation forKey:nil];
    }
    

    return parentLayer;
}

- (CALayer *)makeImageLayer {

    // Listing 12.2
    CGSize size = _image.size;
    CALayer *layer = [CALayer layer];
    layer.contents = (id)_image.CGImage;
    layer.allowsEdgeAntialiasing = YES;
    layer.bounds = CGRectMake(0, 0, size.width, size.height);
    layer.position = CGPointMake(CGRectGetMidX(_bounds) - 20, 270);
    return layer;
}

- (CALayer *)makeTextLayer {

    // Listing 12.2
    CGFloat fontSize = _useLargeFont ? 64 : 54;
    UIFont *font = [UIFont fontWithName:@"GillSans-Bold" size:fontSize];
    
    NSDictionary *attr = @{
                           NSFontAttributeName: font,
                           NSForegroundColorAttributeName: [UIColor whiteColor]
                           };
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:_text attributes:attr];
    CGSize size = [_text sizeWithAttributes:attr];
    CATextLayer *textLayer = [CATextLayer layer];
    textLayer.string = string;
    textLayer.bounds = CGRectMake(0, 0, size.width, size.height);
    textLayer.position = CGPointMake(CGRectGetMidX(_bounds), 470);
    textLayer.backgroundColor = [UIColor clearColor].CGColor;
    return textLayer;
}

- (CAAnimation *)makeFadeInFadeOutAnimation {

    // Listing 12.3
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = @[@0, @1, @1, @0];
    animation.keyTimes = @[@0, @0.2, @0.8, @1];
    animation.beginTime = CMTimeGetSeconds(self.startTimeInTimeline);
    animation.duration = CMTimeGetSeconds(self.timeRange.duration);
    animation.removedOnCompletion = NO;
    return animation;
}

- (CAAnimation *)make3DSpinAnimation {

    // Listing 12.5
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.y"];
    animation.toValue = @(4 * M_PI * -1);
    animation.beginTime = CMTimeGetSeconds(self.startTimeInTimeline) + 0.2;
    animation.duration = CMTimeGetSeconds(self.timeRange.duration) * 0.4;
    animation.autoreverses = YES;
    animation.removedOnCompletion = NO;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    return animation;
}

- (CAAnimation *)makePopAnimationWithTimingOffset:(NSTimeInterval)offset {

    // Listing 12.5
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    animation.toValue = @1.3;
    animation.beginTime = offset;
    animation.duration = 0.35;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.autoreverses = YES;
    animation.removedOnCompletion = NO;
    return animation;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused"

static CATransform3D THMakePerspectiveTransform(CGFloat eyePosition) {
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / eyePosition;
    return transform;
}

#pragma clang diagnostic pop

@end
