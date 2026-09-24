#import <Foundation/Foundation.h>

@interface HTTPReporter : NSObject

// URL backend + token per-device dibaca dari config plist di device
// (lihat Config.h) supaya bisa diganti tanpa rebuild. Pola pipeline
// (device -> Flask receiver -> Wazuh) sama seperti proyek Android
// wazuh-mobile-sentinel.
+ (NSString *)receiverURL;
+ (NSString *)authToken;

+ (void)sendPosture:(NSDictionary *)posture;

@end
