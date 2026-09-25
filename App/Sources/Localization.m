#import "Localization.h"

NSString * const NPLanguageDidChangeNotification = @"NPLanguageDidChangeNotification";

static NSString * const kLanguageDefaultsKey = @"nopticore_app_language";

@implementation Localization

+ (NSString *)currentLanguage {
    NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:kLanguageDefaultsKey];
    return saved.length > 0 ? saved : @"id";
}

+ (void)setLanguage:(NSString *)language {
    [[NSUserDefaults standardUserDefaults] setObject:language forKey:kLanguageDefaultsKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:NPLanguageDidChangeNotification object:nil];
}

+ (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)table {
    static NSDictionary *table = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = @{
            // Splash
            @"splash.tagline": @{@"id": @"inti pengamatan yang selalu siaga untuk device kamu",
                                  @"en": @"the watchful core for your device fleet"},

            // Tab titles
            @"tab.status": @{@"id": @"Status", @"en": @"Status"},
            @"tab.config": @{@"id": @"Config", @"en": @"Config"},
            @"tab.about": @{@"id": @"Info", @"en": @"About"},

            // Status screen
            @"status.title": @{@"id": @"Nopticore", @"en": @"Nopticore"},
            @"status.health.active.title": @{@"id": @"Daemon Aktif", @"en": @"Daemon Active"},
            @"status.health.needsCheck.title": @{@"id": @"Daemon Perlu Diperiksa", @"en": @"Daemon Needs Attention"},
            @"status.health.notInstalled": @{@"id": @"LaunchDaemon tidak ditemukan di device ini.",
                                              @"en": @"LaunchDaemon was not found on this device."},
            @"status.health.lastReport": @{@"id": @"Lapor terakhir: %@", @"en": @"Last reported: %@"},
            @"status.health.lastReportStale": @{@"id": @"Lapor terakhir: %@ (lebih dari 15 menit lalu)",
                                                 @"en": @"Last reported: %@ (more than 15 minutes ago)"},
            @"status.section.device": @{@"id": @"Device", @"en": @"Device"},
            @"status.section.daemon": @{@"id": @"Daemon Nopticore", @"en": @"Nopticore Daemon"},
            @"status.section.log": @{@"id": @"Log Terbaru", @"en": @"Recent Log"},
            @"status.row.model": @{@"id": @"Model", @"en": @"Model"},
            @"status.row.ios": @{@"id": @"iOS", @"en": @"iOS"},
            @"status.row.deviceId": @{@"id": @"Device ID", @"en": @"Device ID"},
            @"status.row.deviceId.none": @{@"id": @"belum ada", @"en": @"not generated yet"},
            @"status.row.launchDaemon": @{@"id": @"LaunchDaemon", @"en": @"LaunchDaemon"},
            @"status.row.launchDaemon.installed": @{@"id": @"Terpasang", @"en": @"Installed"},
            @"status.row.launchDaemon.notFound": @{@"id": @"Tidak ditemukan", @"en": @"Not found"},
            @"status.row.backendUrl": @{@"id": @"Backend URL", @"en": @"Backend URL"},
            @"status.row.backendUrl.unset": @{@"id": @"(belum diset)", @"en": @"(not set)"},
            @"status.row.tier": @{@"id": @"Tier", @"en": @"Tier"},
            @"status.row.interval": @{@"id": @"Interval", @"en": @"Interval"},
            @"status.row.interval.value": @{@"id": @"%@ detik", @"en": @"%@ seconds"},
            @"status.empty.title": @{@"id": @"Daemon Belum Pernah Jalan",
                                      @"en": @"Daemon Hasn't Run Yet"},
            @"status.empty.subtitle": @{@"id": @"Belum ada log yang terbaca. Pastikan LaunchDaemon sudah terpasang dan device sudah di-restart sekali setelah instalasi.",
                                         @"en": @"No log has been read yet. Make sure the LaunchDaemon is installed and the device has been restarted once after installation."},

            // Config screen
            @"config.title": @{@"id": @"Config", @"en": @"Config"},
            @"config.section.header": @{@"id": @"Koneksi Backend", @"en": @"Backend Connection"},
            @"config.section.footer": @{@"id": @"Perubahan di sini menulis langsung ke config plist yang dibaca daemon nopticored. Tidak perlu SSH manual.",
                                         @"en": @"Changes here write directly to the config plist read by the nopticored daemon. No manual SSH needed."},
            @"config.row.backendUrl": @{@"id": @"Backend URL", @"en": @"Backend URL"},
            @"config.row.authToken": @{@"id": @"Auth Token", @"en": @"Auth Token"},
            @"config.row.tier": @{@"id": @"Tier", @"en": @"Tier"},
            @"config.row.interval": @{@"id": @"Interval (detik)", @"en": @"Interval (seconds)"},
            @"config.save": @{@"id": @"Simpan", @"en": @"Save"},
            @"config.saved.title": @{@"id": @"Tersimpan", @"en": @"Saved"},
            @"config.saved.message": @{@"id": @"Config diperbarui. Daemon akan pakai nilai baru di siklus berikutnya (maksimal beberapa menit lagi).",
                                        @"en": @"Config updated. The daemon will use the new values on its next cycle (within a few minutes)."},
            @"config.saveFailed.title": @{@"id": @"Gagal Menyimpan", @"en": @"Save Failed"},
            @"config.saveFailed.message": @{@"id": @"Gagal menulis file config. Cek storage/permission.",
                                             @"en": @"Failed to write the config file. Check storage/permissions."},
            @"common.ok": @{@"id": @"OK", @"en": @"OK"},

            // About screen
            @"about.tagline": @{@"id": @"Node Observability Platform: Trust Intelligence CORE",
                                 @"en": @"Node Observability Platform: Trust Intelligence CORE"},
            @"about.version": @{@"id": @"Versi %@", @"en": @"Version %@"},
            @"about.section.language": @{@"id": @"Bahasa", @"en": @"Language"},
            @"about.section.links": @{@"id": @"Tautan", @"en": @"Links"},
            @"about.link.github": @{@"id": @"Repository GitHub", @"en": @"GitHub Repository"},
            @"about.section.description": @{@"id": @"Tentang", @"en": @"About"},
            @"about.description": @{
                @"id": @"Nopticore memantau device iOS jailbreak-mu untuk mendeteksi proses berbahaya, tweak mencurigakan, dan perubahan lain yang mengancam keamanan device. Data posture dikirim ke Wazuh manager pribadi lewat backend Flask.",
                @"en": @"Nopticore monitors your jailbroken iOS device to detect malicious processes, suspicious tweaks, and other changes that threaten device security. Posture data is sent to a personal Wazuh manager through a Flask backend."
            },
        };
    });
    return table;
}

+ (NSString *)stringForKey:(NSString *)key {
    NSDictionary<NSString *, NSString *> *entry = [self table][key];
    if (!entry) return key; // fallback: tampilin key-nya biar gampang ketauan kalau ada yg lupa didaftarin
    NSString *lang = [self currentLanguage];
    return entry[lang] ?: entry[@"id"] ?: key;
}

@end

NSString *NPL(NSString *key) {
    return [Localization stringForKey:key];
}
