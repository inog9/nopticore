#import "HTTPReporter.h"
#import "Config.h"

@implementation HTTPReporter

+ (NSString *)receiverURL {
    return [Config backendURL];
}

+ (NSString *)authToken {
    return [Config authToken];
}

+ (void)sendPosture:(NSDictionary *)posture {
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:posture
                                                         options:0
                                                           error:&jsonError];
    if (jsonError) {
        NSLog(@"[nopticored] gagal serialize JSON: %@", jsonError);
        return;
    }

    NSURL *url = [NSURL URLWithString:[self receiverURL]];
    if (!url) {
        NSLog(@"[nopticored] backend URL tidak valid, skip kirim");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    // AUDIT: token per-device WAJIB -- backend Flask menolak tanpa ini.
    NSString *token = [self authToken];
    if (token.length > 0) {
        [request setValue:[NSString stringWithFormat:@"Bearer %@", token]
       forHTTPHeaderField:@"Authorization"];
    } else {
        NSLog(@"[nopticored] PERINGATAN: auth_token kosong, request kemungkinan ditolak backend (401)");
    }

    request.timeoutInterval = 15.0;

    // Daemon jalan di background terus (tanpa run loop UI), jadi request
    // di-block via semaphore. NSURLSession jalan di atas GCD, jadi ini aman
    // tanpa CFRunLoop (lihat arsitektur Audit 13.5).
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[nopticored] gagal kirim posture: %@", error);
        } else {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"[nopticored] posture terkirim, status: %ld", (long)httpResponse.statusCode);
        }
        dispatch_semaphore_signal(sema);
    }];
    [task resume];
    // Timeout semaphore sedikit lebih besar dari request timeout, supaya
    // completion handler sempat jalan sebelum kita lanjut.
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20 * NSEC_PER_SEC)));
}

@end
