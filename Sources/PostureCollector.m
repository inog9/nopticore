#import "PostureCollector.h"
#import "Config.h"
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <sys/statvfs.h>

@implementation PostureCollector

// AUDIT 13.4: `kern.uuid` bukan sysctl key yang valid di Darwin/iOS untuk
// device identifier stabil. Generate UUID sekali, simpan ke file lokal,
// baca dari situ di run berikutnya -- ini yang jadi device_id yang stabil.
static NSString * const kDeviceIDPath = @"/var/mobile/Library/Preferences/com.ptxyz.nopticore.device_id";

+ (NSString *)persistentDeviceID {
    NSError *readError = nil;
    NSString *existing = [NSString stringWithContentsOfFile:kDeviceIDPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:&readError];
    if (existing.length > 0) {
        return [existing stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
    NSString *newID = (__bridge_transfer NSString *)uuidStr;
    CFRelease(uuid);

    NSError *writeError = nil;
    [newID writeToFile:kDeviceIDPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];
    if (writeError) {
        NSLog(@"[nopticored] gagal simpan device_id: %@", writeError);
    }
    return newID;
}

// AUDIT 13.1: jailbreak modern untuk A8-A11 (iPhone 7, iPad 6th gen) umumnya
// ROOTLESS (Dopamine/palera1n), bukan rootful klasik. Path dpkg & artifact
// berbeda -- deteksi dulu, baru pilih prefix yang sesuai.
+ (NSString *)rootlessPrefix {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:@"/var/jb"]) {
        return @"/var/jb";
    }
    return @""; // rootful -- tidak ada prefix
}

+ (NSString *)sysctlStringForName:(const char *)name {
    size_t size = 0;
    sysctlbyname(name, NULL, &size, NULL, 0);
    if (size == 0) return @"unknown";
    char *value = malloc(size);
    if (!value) return @"unknown";
    sysctlbyname(name, value, &size, NULL, 0);
    // stringWithUTF8String bisa return nil kalau byte-nya bukan UTF-8 valid;
    // fallback ke "unknown" supaya tidak pernah nil masuk ke dictionary posture.
    NSString *result = [NSString stringWithUTF8String:value] ?: @"unknown";
    free(value);
    return result;
}

+ (NSString *)deviceModel {
    // contoh hasil: iPhone9,1 (iPhone 7) atau iPad7,5 (iPad 6th gen)
    return [self sysctlStringForName:"hw.machine"];
}

+ (NSString *)osVersion {
    NSDictionary *sysVersion = [NSDictionary dictionaryWithContentsOfFile:
        @"/System/Library/CoreServices/SystemVersion.plist"];
    NSString *version = sysVersion[@"ProductVersion"] ?: @"unknown";
    NSString *build = sysVersion[@"ProductBuildVersion"] ?: @"unknown";
    return [NSString stringWithFormat:@"%@ (%@)", version, build];
}

// Cek beberapa artifact umum jailbreak. Karena device ini MEMANG
// jailbreak, ini bukan untuk "deteksi" tapi untuk mencatat metode/tooling
// apa yang terpasang -- berguna buat correlation rule di Wazuh kalau
// nanti kamu punya lebih dari satu device jailbreak untuk dibandingkan.
+ (NSArray<NSString *> *)jailbreakArtifactsFound {
    // Cek path rootful DAN rootless (AUDIT 13.1) -- jailbreak modern
    // (Dopamine/palera1n) di A10 umumnya rootless, prefix /var/jb.
    NSArray *relativePaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/Sileo.app",
        @"/Applications/Zebra.app",
        @"/usr/sbin/sshd",
        @"/etc/apt",
        @"/var/lib/dpkg",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",  // ElleKit modern juga sediakan compat symlink di path ini
        @"/usr/lib/libsubstrate.dylib",
        @"/usr/lib/libhooker.dylib",
        @"/usr/lib/libellekit.dylib"                        // AUDIT 13.3: ElleKit, bukan MobileSubstrate lama
    ];
    NSMutableArray *found = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rootlessPrefix = [self rootlessPrefix];
    for (NSString *relPath in relativePaths) {
        if ([fm fileExistsAtPath:relPath]) {
            [found addObject:relPath];
        }
        if (rootlessPrefix.length > 0) {
            NSString *rootlessPath = [rootlessPrefix stringByAppendingString:relPath];
            if ([fm fileExistsAtPath:rootlessPath]) {
                [found addObject:rootlessPath];
            }
        }
    }
    if (rootlessPrefix.length > 0) {
        [found addObject:@"/var/jb (rootless jailbreak terdeteksi)"];
    }
    return found;
}

+ (BOOL)isJailbroken {
    return YES; // daemon ini sendiri hanya jalan di device yang sudah jailbreak
}

// Baca daftar package terinstal dari dpkg (Cydia/Sileo/Zebra semua pakai dpkg backend).
// Ini yang jadi analog ke "InstalledApplicationList" versi Android/MDM.
+ (NSArray<NSDictionary *> *)installedPackages {
    NSMutableArray *packages = [NSMutableArray array];
    // AUDIT 13.1: coba path rootless dulu, lalu BENAR-BENAR fallback ke rootful
    // kalau rootless tidak terbaca (mis. /var/jb ada tapi dpkg-nya di tempat lain).
    NSString *rootlessPrefix = [self rootlessPrefix];
    NSMutableArray<NSString *> *candidatePaths = [NSMutableArray array];
    if (rootlessPrefix.length > 0) {
        [candidatePaths addObject:[rootlessPrefix stringByAppendingString:@"/var/lib/dpkg/status"]];
    }
    [candidatePaths addObject:@"/var/lib/dpkg/status"];  // fallback rootful

    NSString *content = nil;
    for (NSString *path in candidatePaths) {
        NSError *error = nil;
        content = [NSString stringWithContentsOfFile:path
                                            encoding:NSUTF8StringEncoding
                                               error:&error];
        if (content.length > 0) break;  // terbaca, berhenti
    }
    if (!content) {
        return packages; // dpkg status tidak terbaca di path mana pun -- array kosong, jangan crash
    }

    NSArray *entries = [content componentsSeparatedByString:@"\n\n"];
    for (NSString *entry in entries) {
        if (entry.length == 0) continue;
        NSString *pkgName = nil, *pkgVersion = nil, *pkgStatus = nil;
        NSArray *lines = [entry componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            if ([line hasPrefix:@"Package: "]) {
                pkgName = [line substringFromIndex:9];
            } else if ([line hasPrefix:@"Version: "]) {
                pkgVersion = [line substringFromIndex:9];
            } else if ([line hasPrefix:@"Status: "]) {
                pkgStatus = [line substringFromIndex:8];
            }
        }
        // hanya masukkan package yang benar-benar "installed", skip yang di-remove/purge
        if (pkgName && pkgStatus && [pkgStatus containsString:@"installed"]) {
            [packages addObject:@{
                @"name": pkgName,
                @"version": pkgVersion ?: @"unknown"
            }];
        }
    }
    return packages;
}

+ (NSDictionary *)diskUsage {
    // Di rootless, /var tetap mount user yang valid; tapi kalau ada prefix
    // /var/jb, pakai itu supaya angka mencerminkan partisi yang device pakai.
    NSString *prefix = [self rootlessPrefix];
    NSString *pathNS = prefix.length > 0 ? [prefix stringByAppendingString:@"/var"] : @"/var";
    struct statvfs stat;
    if (statvfs([pathNS fileSystemRepresentation], &stat) != 0) {
        return @{@"total_bytes": @0, @"free_bytes": @0};
    }
    unsigned long long total = (unsigned long long)stat.f_blocks * stat.f_frsize;
    unsigned long long freeBytes = (unsigned long long)stat.f_bavail * stat.f_frsize;
    return @{
        @"total_bytes": @(total),
        @"free_bytes": @(freeBytes)
    };
}

+ (NSString *)uptime {
    struct timeval boottime;
    size_t size = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != 0) {
        return @"unknown";
    }
    // Integer arithmetic -- hindari kehilangan presisi lewat NSTimeInterval (double).
    time_t nowSec = time(NULL);
    long long uptimeSeconds = (long long)nowSec - (long long)boottime.tv_sec;
    if (uptimeSeconds < 0) uptimeSeconds = 0;
    return [NSString stringWithFormat:@"%lld", uptimeSeconds];
}

+ (NSDictionary *)collectPosture {
    NSArray *artifacts = [self jailbreakArtifactsFound];
    NSArray *packages = [self installedPackages];

    return @{
        @"device_id": [self persistentDeviceID],
        @"tier": [Config tier],
        @"device_model": [self deviceModel],
        @"os_version": [self osVersion],
        @"is_jailbroken": @([self isJailbroken]),
        @"jailbreak_artifacts": artifacts,
        @"jailbreak_artifact_count": @(artifacts.count),
        @"installed_package_count": @(packages.count),
        @"installed_packages": packages,
        @"disk_usage": [self diskUsage],
        @"uptime_seconds": [self uptime],
        @"timestamp": @((long long)[[NSDate date] timeIntervalSince1970]),
        @"collector_version": @"0.1.0"
    };
}

@end
