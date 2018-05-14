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

#import "THSampleDataFilter.h"

@interface THSampleDataFilter ()
@property (nonatomic, strong) NSData *sampleData;
@end

@implementation THSampleDataFilter

- (id)initWithData:(NSData *)sampleData {
    self = [super init];
    if (self) {
        _sampleData = sampleData;
    }
    return self;
}

- (NSArray *)filteredSamplesForSize:(CGSize)size {

    // Listing 8.5
    NSUInteger length = _sampleData.length / sizeof(SInt16);
    NSInteger bindLength = (NSInteger)(length / size.width);
    NSMutableArray *sampleData = [NSMutableArray arrayWithCapacity:bindLength];

    SInt16 *data = (SInt16 *)_sampleData.bytes;
    SInt16 maxNum = 0;
    for (int i = 0; i < length; i += bindLength) {
//        SInt16 *tempSample = malloc(bindLength);
//        SInt16 tempSample[bindLength] = {0};
        SInt16 tempSample[bindLength];
        for (int j = 0; j < bindLength; j++) {
            tempSample[j] = CFSwapInt16LittleToHost(data[i + j]);
        }
        
        SInt16 max = [self maxValueInArray:tempSample ofSize:bindLength];
        if (max > maxNum) {
            maxNum = max;
        }
//        free(tempSample);
        [sampleData addObject:@(max)];
    }
    CGFloat sacleFactor = (size.height / 2) / maxNum;
    
    for (int i = 0; i < sampleData.count; i++) {
        sampleData[i] = @([(NSNumber *)sampleData[i] integerValue] * sacleFactor);
    }

    return sampleData;
}

- (SInt16)maxValueInArray:(SInt16[])values ofSize:(NSUInteger)size {

    // Listing 8.5
    SInt16 max = 0;
    for (int i = 0; i < size; i++) {
        if (abs(values[i]) > max) {
            max = abs(values[i]);
        }
    }
    return max;
}

@end
