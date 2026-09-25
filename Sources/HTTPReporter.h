#import <Foundation/Foundation.h>

@interface HTTPReporter : NSObject

// URL backend + token per-device dibaca dari config plist di device
// (lihat Config.h) supaya bisa diganti tanpa rebuild. Pipeline: device ->
// Flask receiver -> Wazuh, untuk deteksi dini proses berbahaya di device
// jailbreak.
+ (NSString *)receiverURL;
+ (NSString *)authToken;

+ (void)sendPosture:(NSDictionary *)posture;

@end
