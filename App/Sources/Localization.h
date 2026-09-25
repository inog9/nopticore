#import <Foundation/Foundation.h>

// Localization ringan dengan TOGGLE MANUAL di dalam app (bukan ngikut bahasa
// sistem) -- makanya bukan pakai NSLocalizedString/.lproj bawaan Xcode biasa
// (itu ngikut Settings > Language device, gak ada tombol switch di app).
// Semua string didaftarkan manual di NopticoreLocalizationTable() (Localization.m).
@interface Localization : NSObject

// "id" atau "en". Default "id" kalau belum pernah diset user.
+ (NSString *)currentLanguage;
+ (void)setLanguage:(NSString *)language;

+ (NSString *)stringForKey:(NSString *)key;

@end

// Notification di-post tiap bahasa berubah -- view controller yang lagi
// tampil harus observe ini dan refresh teks-nya sendiri.
extern NSString * const NPLanguageDidChangeNotification;

// Shorthand supaya pemanggilan di kode gak kepanjangan.
FOUNDATION_EXPORT NSString *NPL(NSString *key);
