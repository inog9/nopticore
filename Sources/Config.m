#import "Config.h"

@implementation Config

static NSString * const kConfigPath =
    @"/var/mobile/Library/Preferences/com.ptxyz.nopticore.config.plist";

// Default aman kalau config belum dibuat -- daemon tetap jalan tapi
// kirim ke placeholder (yang akan gagal DNS), bukan crash.
static NSString * const kDefaultBackendURL = @"https://YOUR-FLASK-BACKEND/ingest/ios";
static NSString * const kDefaultTier = @"full";
static const NSTimeInterval kDefaultInterval = 300.0;

+ (NSDictionary *)load {
    NSDictionary *cfg = [NSDictionary dictionaryWithContentsOfFile:kConfigPath];
    return cfg ?: @{};
}

+ (NSString *)backendURL {
    NSString *v = [self load][@"backend_url"];
    return (v.length > 0) ? v : kDefaultBackendURL;
}

+ (NSString *)authToken {
    NSString *v = [self load][@"auth_token"];
    return v ?: @"";   // kosong -> request akan ditolak backend, sesuai desain
}

+ (NSString *)tier {
    NSString *v = [self load][@"tier"];
    return (v.length > 0) ? v : kDefaultTier;
}

+ (NSTimeInterval)reportInterval {
    id v = [self load][@"interval"];
    if ([v isKindOfClass:[NSNumber class]]) {
        NSTimeInterval interval = [v doubleValue];
        if (interval >= 30.0) {  // jangan terlalu agresif di device tua
            return interval;
        }
    }
    return kDefaultInterval;
}

@end
