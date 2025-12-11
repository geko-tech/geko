#import <Foundation/Foundation.h>
#import "ObjcSpmLogger.h"

@implementation ObjcSpmLogger

- (void)logMessage {
    NSString *localized = NSLocalizedStringFromTableInBundle(@"HelloKey", nil, ObjcSpm_SWIFTPM_MODULE_BUNDLE(), @"");
    NSLog(@"Hello from objc spm logger!\nAnd %@", localized);
}

@end
