#import "TonyObjC.h"

@implementation AVAudioEngine (Tony)

- (BOOL)tonyConnect:(AVAudioNode *)node to:(AVAudioNode *)other format:(AVAudioFormat *)format error:(NSError **)error {
    @try {
        [self connect:node to:other format:format];
        return YES;
    } @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:exception.name code:0 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: exception.name}];
        return NO;
    }
}

@end
