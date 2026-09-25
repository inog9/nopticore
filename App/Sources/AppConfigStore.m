#import "AppConfigStore.h"

@implementation AppConfigStore

+ (NSString *)configPath {
    return @"/var/mobile/Library/Preferences/com.ptxyz.nopticore.config.plist";
}

+ (NSDictionary *)load {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[self configPath]];
    return dict ?: @{};
}

+ (BOOL)saveBackendURL:(NSString *)backendURL
              authToken:(NSString *)authToken
                   tier:(NSString *)tier
               interval:(NSInteger)interval {
    NSDictionary *dict = @{
        @"backend_url": backendURL ?: @"",
        @"auth_token": authToken ?: @"",
        @"tier": tier ?: @"full",
        @"interval": @(MAX(interval, 30)) // sama minimum yang dipaksa Config.m daemon
    };
    NSString *path = [self configPath];
    NSString *dir = [path stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [dict writeToFile:path atomically:YES];
}

@end
