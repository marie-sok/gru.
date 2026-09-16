#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C runtime bridge used only by the chat-scoped privacy compositor.
/// Swift resolves this class dynamically so RootView/auth never depend on it.
@interface GRULayerScreenshotShield : NSObject
- (NSNumber *)protectLayer:(CALayer *)layer;
@end

NS_ASSUME_NONNULL_END
