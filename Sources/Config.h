#import <Foundation/Foundation.h>

// Konfigurasi runtime daemon. Nilai dibaca dari sebuah plist di device
// supaya bisa diganti tanpa rebuild -- di fase App (Fase 2), UI Settings
// yang menulis file ini; untuk sekarang buat manual via SSH.
//
// Path: /var/mobile/Library/Preferences/com.ptxyz.nopticore.config.plist
// Isi (plist dict):
//   backend_url : string, contoh "https://nopticore.ptxyz.tech/ingest/ios"
//   auth_token  : string, token unik per-device (Bearer)
//   tier        : string, "full" (jailbreak) atau "lite"
//   interval    : integer (detik), opsional; default 300
//
// Kalau file tidak ada / field kosong, dipakai default di bawah.

@interface Config : NSObject

+ (NSDictionary *)load;                 // baca plist config (atau default)
+ (NSString *)backendURL;
+ (NSString *)authToken;
+ (NSString *)tier;                     // "full" | "lite"
+ (NSTimeInterval)reportInterval;       // detik

@end
