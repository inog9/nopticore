#import <Foundation/Foundation.h>

@interface PostureCollector : NSObject

// Snapshot lengkap posture device, dikembalikan sebagai NSDictionary
// siap di-serialize ke JSON. Field-nya sengaja dinamai mirip proyek
// wazuh-mobile-sentinel (Android) supaya rule Wazuh gampang di-adapt.
+ (NSDictionary *)collectPosture;

// AUDIT 13.4 / 13.1
+ (NSString *)persistentDeviceID;
+ (NSString *)rootlessPrefix;

+ (NSString *)deviceModel;
+ (NSString *)osVersion;
+ (BOOL)isJailbroken;              // selalu true di device ini, disimpan untuk konsistensi skema
+ (NSArray<NSString *> *)jailbreakArtifactsFound;
+ (NSArray<NSDictionary *> *)installedPackages;   // dari dpkg (Cydia/Sileo)
+ (NSDictionary *)diskUsage;
+ (NSString *)uptime;

@end
