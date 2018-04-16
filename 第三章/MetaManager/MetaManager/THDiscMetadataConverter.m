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

#import "THDiscMetadataConverter.h"
#import "THMetadataKeys.h"

@implementation THDiscMetadataConverter

- (id)displayValueFromMetadataItem:(AVMetadataItem *)item {
    
    // Listing 3.14
    NSNumber *number = nil;
    NSNumber *count = nil;
    if ([item.value isKindOfClass:[NSString class]]) {
        NSArray *components = [(NSString *)item.value componentsSeparatedByString:@"/"];
        number = @([components.firstObject integerValue]);
        count = @([components.lastObject integerValue]);
    } else if ([item.value isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)item.value;
        if (data.length == 6) {
            uint16_t *value = (uint16_t *)[data bytes];
            if (value[1] > 0) {
                number = @(CFSwapInt16BigToHost(value[1]));//转换成小端序
            }
            if (value[2] > 0) {
                count = @(CFSwapInt16BigToHost(value[2]));
            }
        }
    }
    
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithCapacity:2];
    [dic setObject:number ?: [NSNull null] forKey:THMetadataKeyDiscNumber];
    [dic setObject:count ?: [NSNull null] forKey:THMetadataKeyDiscCount];
    return [dic copy];
}

- (AVMetadataItem *)metadataItemFromDisplayValue:(id)value
                                withMetadataItem:(AVMetadataItem *)item {
    
    // Listing 3.14
    AVMutableMetadataItem *otherItem = [item mutableCopy];
    NSDictionary *dic = (NSDictionary *)value;
    
    NSNumber *number = dic[THMetadataKeyDiscNumber];
    NSNumber *count = dic[THMetadataKeyDiscCount];
    uint16_t values[3] = {0};
    if (number && ![number isKindOfClass:[NSNull class]]) {
        values[1] = CFSwapInt16HostToBig([number unsignedIntegerValue]);
    }
    if (number && ![number isKindOfClass:[NSNull class]]) {
        values[2] = CFSwapInt16HostToBig([count unsignedIntegerValue]);
    }
    
    NSData *data = [NSData dataWithBytes:values length:sizeof(values)];
    otherItem.value = data;
    return otherItem;
}

@end
