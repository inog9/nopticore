#import "PostureCollector.h"
#import "Config.h"
#import <sys/sysctl.h>
#import <sys/stat.h>
#import <sys/statvfs.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <CommonCrypto/CommonDigest.h>
#import <sys/socket.h>
#import <sys/select.h>
#import <fcntl.h>
#import <errno.h>

// proc_pidpath tidak ada di header SDK publik (butuh libproc.h yang tidak
// disertakan Apple), tapi simbolnya tetap ada di libSystem -- deklarasi
// manual, teknik umum di tool jailbreak.
extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
#define NOPTICORE_PROC_PIDPATHINFO_MAXSIZE (4096)

// csops juga tidak ada di header publik dengan alasan sama. Konstanta di
// bawah diambil dari XNU open source (bsd/sys/codesign.h), bukan header
// privat rahasia -- dipakai luas oleh tool jailbreak untuk baca status
// code-signing proses yang sedang jalan.
extern int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
#define NOPTICORE_CS_OPS_STATUS 0
#define NOPTICORE_CS_VALID 0x00000001
#define NOPTICORE_CS_ADHOC 0x00000002
#define NOPTICORE_CS_GET_TASK_ALLOW 0x00000004
#define NOPTICORE_CS_PLATFORM_BINARY 0x04000000

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

// Alamat IPv4 lokal dari interface WiFi (en0). Cukup pakai getifaddrs()
// standar POSIX -- tidak butuh entitlement khusus (beda dari SSID/BSSID
// yang butuh com.apple.developer.networking.wifi-info di iOS modern).
+ (NSString *)localIPAddress {
    NSString *address = @"unknown";
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        for (struct ifaddrs *interface = interfaces; interface != NULL; interface = interface->ifa_next) {
            if (interface->ifa_addr == NULL || interface->ifa_addr->sa_family != AF_INET) continue;
            NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
            if ([name isEqualToString:@"en0"]) {
                char buf[INET_ADDRSTRLEN];
                struct sockaddr_in *addr = (struct sockaddr_in *)interface->ifa_addr;
                if (inet_ntop(AF_INET, &addr->sin_addr, buf, sizeof(buf))) {
                    address = [NSString stringWithUTF8String:buf];
                }
                break;
            }
        }
    }
    freeifaddrs(interfaces);
    return address;
}

// IOPSCopyPowerSourcesInfo asalnya API macOS -- di iOS device fisik (beda
// dari Simulator) API ini tersedia dan mengembalikan power source baterai.
// level -1 / charging NO dipakai sebagai fallback kalau API gagal.
+ (NSDictionary *)batteryInfo {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:@{
        @"level_percent": @(-1),
        @"charging": @NO
    }];
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    if (blob) {
        CFArrayRef sources = IOPSCopyPowerSourcesList(blob);
        if (sources && CFArrayGetCount(sources) > 0) {
            CFDictionaryRef source = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(sources, 0));
            if (source) {
                CFNumberRef capacity = CFDictionaryGetValue(source, CFSTR(kIOPSCurrentCapacityKey));
                CFStringRef state = CFDictionaryGetValue(source, CFSTR(kIOPSPowerSourceStateKey));
                int level = -1;
                if (capacity) CFNumberGetValue(capacity, kCFNumberIntType, &level);
                BOOL charging = state && CFStringCompare(state, CFSTR(kIOPSACPowerValue), 0) == kCFCompareEqualTo;
                info[@"level_percent"] = @(level);
                info[@"charging"] = @(charging);
            }
        }
        if (sources) CFRelease(sources);
        CFRelease(blob);
    }
    return info;
}

// Baca status code-signing proses lewat syscall csops() -- hanya berlaku
// untuk proses yang SEDANG JALAN (butuh pid aktif), beda dari cek statis
// pada file .app yang butuh parsing Mach-O signature (belum diimplementasi,
// dianggap terlalu berisiko untuk diburu-buru).
+ (NSDictionary *)codeSignStatusForPID:(pid_t)pid {
    uint32_t flags = 0;
    int rv = csops(pid, NOPTICORE_CS_OPS_STATUS, &flags, sizeof(flags));
    if (rv != 0) {
        return @{@"readable": @NO};
    }
    return @{
        @"readable": @YES,
        @"valid": @((flags & NOPTICORE_CS_VALID) != 0),
        @"adhoc_signed": @((flags & NOPTICORE_CS_ADHOC) != 0),
        @"platform_binary": @((flags & NOPTICORE_CS_PLATFORM_BINARY) != 0),
        @"get_task_allow": @((flags & NOPTICORE_CS_GET_TASK_ALLOW) != 0)
    };
}

// Daftar proses yang lagi jalan, lewat sysctl(KERN_PROC_ALL) -- teknik yang
// sama dipakai command `ps`. AUDIT (payload size): device beneran punya
// ~365 proses -- kalau full path + code_sign dikirim buat SEMUANYA, payload
// tembus 107KB (Wazuh OS_MAXSTR cuma 64KB, event ke-drop diam-diam). Karena
// di device real cuma ~1 proses yang gak valid-signed (kernel_task), detail
// lengkap (path + code_sign) HANYA disertakan untuk proses yang mencurigakan
// (invalid/adhoc-signed) -- proses rutin cukup nama+pid+uid, payload jadi
// jauh lebih kecil tanpa kehilangan sinyal yang justru paling penting.
+ (NSArray<NSDictionary *> *)runningProcesses {
    NSMutableArray<NSDictionary *> *processes = [NSMutableArray array];
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) != 0 || size == 0) return processes;

    struct kinfo_proc *procList = malloc(size);
    if (!procList) return processes;

    if (sysctl(mib, 4, procList, &size, NULL, 0) == 0) {
        int count = (int)(size / sizeof(struct kinfo_proc));
        for (int i = 0; i < count; i++) {
            pid_t pid = procList[i].kp_proc.p_pid;
            uid_t uid = procList[i].kp_eproc.e_ucred.cr_uid;
            NSString *name = [NSString stringWithUTF8String:procList[i].kp_proc.p_comm];
            if (name.length == 0) continue;

            NSString *path = @"unknown";
            NSDictionary *codeSign = @{@"readable": @NO};
            if (pid > 0) { // pid 0 = kernel_task, tidak aman dipanggil syscall proc info biasa
                char pathBuf[NOPTICORE_PROC_PIDPATHINFO_MAXSIZE];
                int pathLen = proc_pidpath(pid, pathBuf, sizeof(pathBuf));
                if (pathLen > 0) {
                    path = [NSString stringWithUTF8String:pathBuf] ?: @"unknown";
                }
                codeSign = [self codeSignStatusForPID:pid];
            }

            NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:@{
                @"name": name,
                @"pid": @(pid),
                @"uid": @(uid)
            }];

            BOOL notValid = ![codeSign[@"valid"] boolValue];
            BOOL adhocSigned = [codeSign[@"adhoc_signed"] boolValue];
            if (notValid || adhocSigned) {
                entry[@"path"] = path;
                entry[@"code_sign"] = codeSign;
            }
            [processes addObject:entry];
        }
    }
    free(procList);
    return processes;
}

// App pihak-ketiga (App Store/sideload) -- BUKAN dari dpkg (itu cuma tweak
// Cydia). Scan folder Bundle/Application langsung + baca CFBundleIdentifier
// dari Info.plist tiap .app, jadi tidak butuh private framework
// (LSApplicationWorkspace). App bawaan Apple (com.apple.*) difilter keluar
// karena tidak relevan buat security posture dan bikin list membengkak --
// jumlahnya tetap dicatat lewat appleAppCount.
+ (NSArray<NSDictionary *> *)installedApps {
    NSMutableArray<NSDictionary *> *apps = [NSMutableArray array];
    NSString *rootlessPrefix = [self rootlessPrefix];
    NSMutableArray<NSString *> *candidateDirs = [NSMutableArray array];
    if (rootlessPrefix.length > 0) {
        [candidateDirs addObject:[rootlessPrefix stringByAppendingString:@"/var/containers/Bundle/Application"]];
    }
    [candidateDirs addObject:@"/var/containers/Bundle/Application"];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *bundleDir in candidateDirs) {
        NSArray<NSString *> *containers = [fm contentsOfDirectoryAtPath:bundleDir error:nil];
        if (containers.count == 0) continue;

        for (NSString *containerID in containers) {
            NSString *containerPath = [bundleDir stringByAppendingPathComponent:containerID];
            NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:containerPath error:nil];
            for (NSString *item in items) {
                if (![item hasSuffix:@".app"]) continue;
                NSString *appPath = [containerPath stringByAppendingPathComponent:item];
                NSString *infoPlistPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
                NSString *bundleID = infoPlist[@"CFBundleIdentifier"];
                if (bundleID.length == 0) continue;
                if ([bundleID hasPrefix:@"com.apple."]) continue; // app bawaan Apple, skip

                NSString *displayName = infoPlist[@"CFBundleDisplayName"] ?: infoPlist[@"CFBundleName"] ?: bundleID;
                NSString *version = infoPlist[@"CFBundleShortVersionString"] ?: @"unknown";
                // CATATAN: sengaja TIDAK hash executable-nya. Baca isi binary app
                // lain dari /var/containers/Bundle/Application (data vault app
                // pihak ketiga) memicu SIGKILL dari sandbox saat daemon jalan
                // sebagai LaunchDaemon (walau aman kalau dieksekusi interaktif
                // lewat shell root via SSH) -- diverifikasi lewat bisection test.
                // sha256ForFileAtPath tetap dipertahankan untuk tweak binary
                // (bukan di app container, jadi tidak kena proteksi ini).
                [apps addObject:@{
                    @"bundle_id": bundleID,
                    @"name": displayName,
                    @"version": version
                }];
            }
        }
        if (apps.count > 0) break; // sudah ketemu lewat path ini, jangan hitung dobel dari path lain
    }
    return apps;
}

// SHA256 file dengan CommonCrypto -- dibaca per-chunk (bukan load sekaligus
// ke memory) karena binary app bisa puluhan MB, device ini juga low-RAM.
+ (NSString *)sha256ForFileAtPath:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;

    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    const NSUInteger chunkSize = 1024 * 1024;
    @try {
        while (YES) {
            NSData *chunk = [handle readDataOfLength:chunkSize];
            if (chunk.length == 0) break;
            CC_SHA256_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
        }
    } @catch (NSException *exception) {
        [handle closeFile];
        return nil;
    }
    [handle closeFile];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &ctx);
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

// RAM total (sysctl hw.memsize) + statistik pemakaian lewat host_statistics64
// (Mach API publik, sama yang dipakai Activity Monitor/top).
+ (NSDictionary *)memoryInfo {
    int64_t totalBytes = 0;
    size_t size = sizeof(totalBytes);
    sysctlbyname("hw.memsize", &totalBytes, &size, NULL, 0);

    mach_port_t hostPort = mach_host_self();
    vm_size_t pageSize = 0;
    host_page_size(hostPort, &pageSize);

    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    int64_t freeBytes = 0, activeBytes = 0, wiredBytes = 0;
    if (host_statistics64(hostPort, HOST_VM_INFO64, (host_info64_t)&vmStats, &count) == KERN_SUCCESS) {
        freeBytes = (int64_t)vmStats.free_count * pageSize;
        activeBytes = (int64_t)vmStats.active_count * pageSize;
        wiredBytes = (int64_t)vmStats.wire_count * pageSize;
    }

    return @{
        @"total_bytes": @(totalBytes),
        @"free_bytes": @(freeBytes),
        @"active_bytes": @(activeBytes),
        @"wired_bytes": @(wiredBytes)
    };
}

// Jumlah core CPU (sysctl publik) + thermal state lewat NSProcessInfo
// (API PUBLIK resmi sejak iOS 11, bukan private framework).
+ (NSDictionary *)cpuInfo {
    int physicalCPU = 0, logicalCPU = 0;
    size_t size = sizeof(int);
    sysctlbyname("hw.physicalcpu", &physicalCPU, &size, NULL, 0);
    size = sizeof(int);
    sysctlbyname("hw.logicalcpu", &logicalCPU, &size, NULL, 0);

    NSString *thermalState = @"unknown";
    switch ([[NSProcessInfo processInfo] thermalState]) {
        case NSProcessInfoThermalStateNominal: thermalState = @"nominal"; break;
        case NSProcessInfoThermalStateFair: thermalState = @"fair"; break;
        case NSProcessInfoThermalStateSerious: thermalState = @"serious"; break;
        case NSProcessInfoThermalStateCritical: thermalState = @"critical"; break;
    }

    return @{
        @"physical_cores": @(physicalCPU),
        @"logical_cores": @(logicalCPU),
        @"thermal_state": thermalState
    };
}

+ (NSString *)hostname {
    return [self sysctlStringForName:"kern.hostname"];
}

+ (NSDictionary *)localeInfo {
    NSLocale *locale = [NSLocale currentLocale];
    return @{
        @"timezone": [[NSTimeZone localTimeZone] name],
        @"locale_identifier": [locale localeIdentifier] ?: @"unknown",
        @"preferred_languages": [NSLocale preferredLanguages] ?: @[]
    };
}

// Semua network interface aktif (bukan cuma en0) + alamat IPv4 + MAC address
// (AF_LINK). MAC address kebaca penuh di jailbreak/root; di device biasa
// (non-root) iOS modern selalu random-kan/blok ini.
+ (NSArray<NSDictionary *> *)networkInterfaces {
    NSMutableDictionary<NSString *, NSMutableDictionary *> *byName = [NSMutableDictionary dictionary];
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) == 0) {
        for (struct ifaddrs *ifa = interfaces; ifa != NULL; ifa = ifa->ifa_next) {
            if (ifa->ifa_addr == NULL) continue;
            NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];
            NSMutableDictionary *entry = byName[name];
            if (!entry) {
                entry = [NSMutableDictionary dictionaryWithDictionary:@{@"name": name}];
                byName[name] = entry;
            }

            if (ifa->ifa_addr->sa_family == AF_INET) {
                char buf[INET_ADDRSTRLEN];
                struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;
                if (inet_ntop(AF_INET, &addr->sin_addr, buf, sizeof(buf))) {
                    entry[@"ipv4"] = [NSString stringWithUTF8String:buf];
                }
            } else if (ifa->ifa_addr->sa_family == AF_LINK) {
                struct sockaddr_dl *sdl = (struct sockaddr_dl *)ifa->ifa_addr;
                if (sdl->sdl_alen == 6) {
                    const unsigned char *mac = (unsigned char *)LLADDR(sdl);
                    entry[@"mac"] = [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x",
                        mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]];
                }
            }
        }
        freeifaddrs(interfaces);
    }
    return [byName allValues];
}

// vm.swapusage -- sysctl publik, sama kelas amannya dengan diskUsage/memoryInfo.
+ (NSDictionary *)swapUsage {
    struct xsw_usage swapInfo;
    size_t size = sizeof(swapInfo);
    if (sysctlbyname("vm.swapusage", &swapInfo, &size, NULL, 0) != 0) {
        return @{@"total_bytes": @0, @"used_bytes": @0};
    }
    return @{
        @"total_bytes": @(swapInfo.xsu_total),
        @"used_bytes": @(swapInfo.xsu_used)
    };
}

// Disk usage partisi root "/" -- terpisah dari diskUsage (yang isinya /var,
// disesuaikan prefix rootless). "/" selalu path yang sama di semua jenis
// jailbreak, tidak butuh rootlessPrefix.
+ (NSDictionary *)rootDiskUsage {
    struct statvfs stat;
    if (statvfs("/", &stat) != 0) {
        return @{@"total_bytes": @0, @"free_bytes": @0};
    }
    return @{
        @"total_bytes": @((unsigned long long)stat.f_blocks * stat.f_frsize),
        @"free_bytes": @((unsigned long long)stat.f_bavail * stat.f_frsize)
    };
}

// Nama file .plist di folder LaunchDaemons -- coba prefix rootless dulu,
// fallback rootful, GENERIK untuk device manapun (tidak diasumsikan device
// ini doang). Kalau folder tidak ada di kedua path, balikin array kosong
// (bukan crash) -- device lain mungkin punya struktur berbeda sama sekali.
+ (NSArray<NSString *> *)persistentDaemons {
    NSString *rootlessPrefix = [self rootlessPrefix];
    NSMutableArray<NSString *> *candidateDirs = [NSMutableArray array];
    if (rootlessPrefix.length > 0) {
        [candidateDirs addObject:[rootlessPrefix stringByAppendingString:@"/Library/LaunchDaemons"]];
    }
    [candidateDirs addObject:@"/Library/LaunchDaemons"];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *dir in candidateDirs) {
        NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:dir error:nil];
        if (files.count > 0) {
            return [files filteredArrayUsingPredicate:
                [NSPredicate predicateWithFormat:@"SELF ENDSWITH '.plist'"]];
        }
    }
    return @[]; // tidak ketemu di path manapun -- device lain mungkin beda struktur, jangan crash
}

// Agregasi dari array proses yang SUDAH dikumpulkan runningProcesses --
// tidak ada syscall tambahan, cuma hitung ulang field "uid" yang sudah ada.
+ (NSDictionary *)processCountByOwner:(NSArray<NSDictionary *> *)processes {
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (NSDictionary *proc in processes) {
        NSNumber *uidNum = proc[@"uid"];
        if (!uidNum) continue;
        NSString *owner;
        switch (uidNum.unsignedIntValue) {
            case 0: owner = @"root"; break;
            case 501: owner = @"mobile"; break;
            default: owner = [NSString stringWithFormat:@"uid_%@", uidNum]; break;
        }
        counts[owner] = @(counts[owner].integerValue + 1);
    }
    return counts;
}

// Cek port TCP localhost beneran listening, pakai non-blocking connect +
// select dengan timeout pendek -- tidak akan menggantung device kalau
// port-nya tertutup (beda dari connect() blocking biasa).
+ (BOOL)isPortOpenOnLocalhost:(uint16_t)port {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return NO;

    int flags = fcntl(sock, F_GETFL, 0);
    fcntl(sock, F_SETFL, flags | O_NONBLOCK);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);

    BOOL isOpen = NO;
    int rv = connect(sock, (struct sockaddr *)&addr, sizeof(addr));
    if (rv == 0) {
        isOpen = YES;
    } else if (errno == EINPROGRESS) {
        fd_set writeSet;
        FD_ZERO(&writeSet);
        FD_SET(sock, &writeSet);
        struct timeval timeout = {.tv_sec = 1, .tv_usec = 0};
        if (select(sock + 1, NULL, &writeSet, NULL, &timeout) > 0) {
            int soError = 0;
            socklen_t len = sizeof(soError);
            getsockopt(sock, SOL_SOCKET, SO_ERROR, &soError, &len);
            isOpen = (soError == 0);
        }
    }
    close(sock);
    return isOpen;
}

+ (NSDictionary *)collectPosture {
    NSArray *artifacts = [self jailbreakArtifactsFound];
    NSArray *packages = [self installedPackages];
    NSArray<NSDictionary *> *processes = [self runningProcesses];
    NSArray<NSDictionary *> *apps = [self installedApps];

    return @{
        @"device_id": [self persistentDeviceID],
        @"tier": [Config tier],
        @"device_model": [self deviceModel],
        @"os_version": [self osVersion],
        @"hostname": [self hostname],
        @"is_jailbroken": @([self isJailbroken]),
        @"jailbreak_artifacts": artifacts,
        @"jailbreak_artifact_count": @(artifacts.count),
        @"installed_package_count": @(packages.count),
        @"installed_packages": packages,
        @"local_ip": [self localIPAddress],
        @"network_interfaces": [self networkInterfaces],
        @"battery": [self batteryInfo],
        @"memory": [self memoryInfo],
        @"cpu": [self cpuInfo],
        @"locale": [self localeInfo],
        @"running_process_count": @(processes.count),
        @"running_processes": processes,
        @"installed_app_count": @(apps.count),
        @"installed_apps": apps,
        @"disk_usage": [self diskUsage],
        @"root_disk_usage": [self rootDiskUsage],
        @"swap_usage": [self swapUsage],
        @"persistent_daemons": [self persistentDaemons],
        @"process_count_by_owner": [self processCountByOwner:processes],
        @"ssh_port_open": @([self isPortOpenOnLocalhost:22]),
        @"uptime_seconds": [self uptime],
        @"timestamp": @((long long)[[NSDate date] timeIntervalSince1970]),
        @"collector_version": @"0.4.0"
    };
}

@end
