#import <Foundation/Foundation.h>

// Baca/tulis config plist yang SAMA dipakai daemon nopticored (Config.m).
// App ini jalan sebagai user "mobile" (tidak root), tapi /var/mobile itu
// writable normal untuk user mobile, jadi tidak butuh privilege khusus.
@interface AppConfigStore : NSObject

+ (NSString *)configPath;

+ (NSDictionary *)load;
+ (BOOL)saveBackendURL:(NSString *)backendURL
              authToken:(NSString *)authToken
                   tier:(NSString *)tier
               interval:(NSInteger)interval;

@end
