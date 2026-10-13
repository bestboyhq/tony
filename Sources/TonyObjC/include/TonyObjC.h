#import <AVFAudio/AVFAudio.h>

NS_ASSUME_NONNULL_BEGIN

@interface AVAudioEngine (Tony)
/// `connect:to:format:` that fails instead of ending the app: it raises an Objective-C exception, which
/// Swift can't catch, when the hardware's format changes under it. macOS 27 has `connectNode` for this.
- (BOOL)tonyConnect:(AVAudioNode *)node to:(AVAudioNode *)other format:(nullable AVAudioFormat *)format error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
