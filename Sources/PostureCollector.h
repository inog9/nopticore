#import <Foundation/Foundation.h>

@interface PostureCollector : NSObject

// Snapshot lengkap posture device, dikembalikan sebagai NSDictionary
// siap di-serialize ke JSON dan dikirim ke Wazuh untuk deteksi proses
// berbahaya/ancaman di device jailbreak.
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

+ (NSString *)localIPAddress;
+ (NSDictionary *)batteryInfo;
+ (NSArray<NSDictionary *> *)runningProcesses;     // {name, pid, path, code_signed, cs_flags}
+ (NSArray<NSDictionary *> *)installedApps;        // app pihak-ketiga (com.apple.* difilter)

+ (NSDictionary *)memoryInfo;
+ (NSDictionary *)cpuInfo;
+ (NSString *)hostname;
+ (NSDictionary *)localeInfo;
+ (NSArray<NSDictionary *> *)networkInterfaces;    // semua interface + IPv4 + MAC
+ (NSString *)sha256ForFileAtPath:(NSString *)path;

+ (NSDictionary *)swapUsage;
+ (NSDictionary *)rootDiskUsage;
+ (NSArray<NSString *> *)persistentDaemons;        // nama file .plist di LaunchDaemons (rootless/rootful)
+ (NSDictionary *)processCountByOwner:(NSArray<NSDictionary *> *)processes; // agregasi dari runningProcesses, tanpa syscall baru
+ (BOOL)isPortOpenOnLocalhost:(uint16_t)port;

@end
