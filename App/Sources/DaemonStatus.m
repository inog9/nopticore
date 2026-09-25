#import "DaemonStatus.h"
#import <sys/stat.h>

@implementation DaemonStatus

+ (NSString *)rootlessPrefix {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:@"/var/jb"]) {
        return @"/var/jb";
    }
    return @"";
}

+ (NSString *)logPath {
    NSString *rootlessPrefix = [self rootlessPrefix];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rootlessPath = [rootlessPrefix stringByAppendingString:@"/var/log/nopticored.log"];
    if (rootlessPrefix.length > 0 && [fm isReadableFileAtPath:rootlessPath]) {
        return rootlessPath;
    }
    return @"/var/log/nopticored.log";
}

+ (NSArray<NSString *> *)recentLogLines:(NSInteger)maxLines {
    NSString *path = [self logPath];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!content) return @[];

    NSArray<NSString *> *allLines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *nonEmpty = [NSMutableArray array];
    for (NSString *line in allLines) {
        if (line.length > 0) [nonEmpty addObject:line];
    }
    if (nonEmpty.count <= maxLines) return nonEmpty;
    return [nonEmpty subarrayWithRange:NSMakeRange(nonEmpty.count - maxLines, maxLines)];
}

+ (NSDate *)lastLogActivity {
    NSString *path = [self logPath];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    return attrs[NSFileModificationDate];
}

+ (BOOL)isLaunchDaemonInstalled {
    NSString *rootlessPrefix = [self rootlessPrefix];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *rootlessPlist = [rootlessPrefix stringByAppendingString:@"/Library/LaunchDaemons/com.ptxyz.nopticored.plist"];
    if (rootlessPrefix.length > 0 && [fm fileExistsAtPath:rootlessPlist]) return YES;
    return [fm fileExistsAtPath:@"/Library/LaunchDaemons/com.ptxyz.nopticored.plist"];
}

@end
