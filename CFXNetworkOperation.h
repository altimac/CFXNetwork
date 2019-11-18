//
//  CFXNetworkOperation.h
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 2016 Carrafix. All rights reserved.
//

// A base class to perform an atomic/isolated network operation, as AFNetwork 3.x became too cumbersome and clunky (mostly because NSURLSession is hard to maintain in an NSOperation).
// Each request should be isolated in an NSOperation. Dependencies, parallelism, queue/thread, prioritization etc... can be controled through NSOperation/Queue APIs.

// This class must be subclassed and you should override -processIncomingDataWithError:.
// You can also override -validateResponse:withError:

// The idea is that you need very minimum properties should be set. Only the ones in argument of the designated initializer are compulsory!

// TODO: handle operation retrying (such as 3x per default with delay?). Should be configurable

#import <Foundation/Foundation.h>

@class CFXNetworkOperation;

NS_ASSUME_NONNULL_BEGIN

typedef void(^CFXNetworkOperationResponseBlock_t)(CFXNetworkOperation *operation, id responseObject, NSError *error);
typedef NSData * _Nullable (^CFXNetworkOperationBodyBuilderBlock_t)(void);

@interface CFXNetworkOperation : NSOperation <NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate, NSProgressReporting>

@property(nullable, readonly) NSMutableSet<NSString*> *allowedMimeTypes; // empty by default, means allow everything
@property(nullable, readonly) NSMutableData *incomingData; // data received by the client. Mutable to ease subclassing. Do not mutate it except if you know what you're doing :)
@property(nonatomic, nullable) NSURLSessionConfiguration *localConfig; // default to [NSURLSessionConfiguration defaultSessionConfiguration]. The receiver must not be started (isExecuting==YES) to set that property.
@property(readonly, copy) NSString *method; // POST, GET, DELETE...
@property(readonly, copy) NSString *urlString; // http://www.mywebservice.com/api/v2
@property(nullable, readonly) NSDictionary<NSString *, NSString*> *requestParameters; // ?key1=value1&key2=value2...
@property(nullable) NSData *body; // should be set before the operation is started. Alternatively, use bodyBuilderBlock to build the body *asynchronously*, on demand on a the NSOperation's queue
@property(nullable, copy) CFXNetworkOperationBodyBuilderBlock_t bodyBuilderBlock; // should be set before the operation is started. Called *asynchronously*, on demand on the NSOperation's queue to *build* the body (and set it). Auto nullified after use to avoid possible retain cycles
@property(assign) BOOL gzipBody; // Defaults to NO. should be set before the operation is started. Called asynchronously, on the NSOperation's queue, after the bodyBuilderBlock or after the body has been set. It gzip compresses the body and adds "Content-Encoding: gzip" to request headers if body length > 1024 bytes. It compresses the *request body*, it does not handles the responses decompression which is automagically handled by NSURLSession/NSURLConnection!
@property(nullable) NSDictionary *additionalHeaders;  // custom HTTP header fields, should be set before the operation is started. NOTE: Currently also testing the use of localConfig.HTTPAdditionalHeaders instead?? what difference??
@property(assign) BOOL allowEmptyResponse; // Allows server to only return an HTTP response, but with no body. Defaults to NO. Can be useful when the server responds status 200 OK but with no body instead of something like "true" or "1".

@property(strong) NSProgress *progress; // mostly based on (expected) Content-Length.

@property(readonly) NSURLRequest *request;
@property(readonly) NSHTTPURLResponse *response;
@property(nullable, readonly) id responseObject; // typically the "object" the server will respond. Does not make sense in this abstract class. In subclasses this make more sense (generally the decoded JSON/XML body as an object). Also see "incomingData" above.
@property(nullable) NSError *error; // set readwrite as higher level objects may override the Operation error (or set to another "higher level" error) any time to propagate it higher in the app.

@property(copy, nullable) CFXNetworkOperationResponseBlock_t responseBlock; // note that the response block is called asynchronously, *AFTER* the operation is considered finished! Auto nullified after it's called to avoid possible retain cycles
@property(nonatomic, nullable) dispatch_queue_t responseQueue; // or NSOperationQueue? defaults to nil. nil is main queue

- (instancetype)initWithMethod:(NSString *)method urlString:(NSString *)urlString parameters:(nullable NSDictionary<NSString *, NSString *> *)requestParameters;

NS_ASSUME_NONNULL_END

@end
