#import <Foundation/Foundation.h>

// Baca status daemon nopticored dari luar (app tidak root, jadi cuma bisa
// BACA file yang readable, tidak bisa start/stop daemon langsung -- itu
// sengaja, biar tidak perlu entitlement/privilege tambahan di app).
@interface DaemonStatus : NSObject

// Path log daemon -- coba prefix rootless dulu, fallback rootful, generik
// untuk device manapun (pola yang sama dengan PostureCollector).
+ (NSString *)logPath;

// Beberapa baris terakhir dari log daemon, atau nil kalau tidak terbaca
// (misal permission, atau daemon belum pernah jalan).
+ (NSArray<NSString *> *)recentLogLines:(NSInteger)maxLines;

// Waktu modifikasi terakhir file log -- proxy untuk "kapan terakhir daemon aktif".
+ (NSDate *)lastLogActivity;

+ (BOOL)isLaunchDaemonInstalled;

@end
