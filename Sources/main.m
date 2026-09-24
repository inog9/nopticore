#import <Foundation/Foundation.h>
#import "PostureCollector.h"
#import "HTTPReporter.h"
#import "Config.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[nopticored] daemon started");

        while (1) {
            @autoreleasepool {
                NSDictionary *posture = [PostureCollector collectPosture];
                NSLog(@"[nopticored] posture collected: %@ packages, %lu jailbreak artifacts (tier=%@)",
                      posture[@"installed_package_count"],
                      (unsigned long)[posture[@"jailbreak_artifacts"] count],
                      posture[@"tier"]);
                [HTTPReporter sendPosture:posture];

                // Interval dibaca dari Config (default 300s) -- bisa diganti
                // tanpa rebuild lewat config plist. sleep() minta unsigned int,
                // jadi di-cast eksplisit dari NSTimeInterval.
                NSTimeInterval interval = [Config reportInterval];
                sleep((unsigned int)interval);
            }
        }
    }
    return 0;
}
