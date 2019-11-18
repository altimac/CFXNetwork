//
//  CFXNetworkOperation_private.h
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 20016 Carrafix. All rights reserved.
//

#import "CFXNetworkOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface CFXNetworkOperation ()
{
    // renders the finished property readwrite. But unfortunately NSOperationQueue is listening for "isFinished" notification instead of "finished"
    // Important note, as of iOS 11/macOS 10.13 it seems that changed: https://developer.apple.com/library/content/releasenotes/Foundation/RN-Foundation/index.html
    BOOL _finished;
}

@property(readwrite) NSMutableData *incomingData;
@property(nonatomic, nullable) NSURLSessionTask *sessionTask;
@property(nonatomic, nullable) NSURLSession *localURLSession;
@property(readwrite, copy) NSString *method; // POST, GET, DELETE...
@property(readwrite, copy) NSString *urlString; // http://www.mywebservice.com/api/v2
@property(nullable, readwrite) NSDictionary<NSString *, NSString *> *requestParameters; // ?key1=value1&key2=value2...

@property(readwrite) NSURLRequest *request;
@property(readwrite) NSHTTPURLResponse *response;
@property(nullable, readwrite) id responseObject;
//@property(readwrite) NSError *error;

@property(readwrite, getter=isFinished) BOOL finished; // render the finished property readwrite but maintain KVO on "isFinished" (see _finished comment above)

#pragma mark - Protected, meant to be overriden

-(BOOL)validateResponse:(NSHTTPURLResponse *)response withError:(NSError **)error __attribute__((objc_requires_super)); // typically to handle HTTP status code
-(BOOL)processIncomingDataWithError:(NSError **)error; // mostly to decode body (JSON, Plist, XML whatever)
-(void)callResponseBlockAsynchronously; // can be helpful to override if you want typically want to handle custom server errors (when the server returns HTTP status code 200 (aka OK), but in the body of the response the server says there is an error: typically a JSON object like {"success: false, "error: bla error bla invalid request")}. You can then at the end return an error/failure to the caller, when in fact, at the HTTP level, it's not an error. Can also be used to do many other things such as benchmarking, logging...


@end

NS_ASSUME_NONNULL_END
