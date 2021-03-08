//
//  CFXNetworkOperation.m
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 2016 Carrafix. All rights reserved.

#import "CFXNetworkOperation.h"
#import "CFXNetworkOperation_private.h"
#import "NSData+ZipCompression.h"


#define DEFAULT_BODY_LENGTH_GZIP_THRESHOLD 1024 // in bytes. If the body data length is > 1024 bytes, and if gzipBody is set to YES, we'll gzip the body data. Under that threshold, it's not useful as it's small anyway.

@interface CFXNetworkOperation ()

@end

@implementation CFXNetworkOperation

- (instancetype)initWithMethod:(NSString *)method urlString:(NSString *)urlString parameters:(nullable NSDictionary<NSString *, NSString *> *)requestParameters
{
    self = [super init];
    if (self) {
        _allowedMimeTypes = [[NSMutableSet alloc] init];
        _method = method;
        _urlString = urlString;
        _requestParameters = requestParameters;
        _localConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        _responseQueue = dispatch_get_main_queue();
        
        _progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    }
    return self;
}

-(void)start
{
    if([self isCancelled]) {
        self.finished = YES;
        return;
    }
    
    NSError *error;
    self.request = [self serializeRequestWithMethod:_method urlString:_urlString requestParameters:_requestParameters error:&error];
    if(self.request == nil)
    {
        self.error = error;
        self.responseObject = nil;
        self.finished = YES;
        
        // breaks the retain cycles!
        [_localURLSession invalidateAndCancel];
        _localURLSession = nil;
        
        [self callResponseBlockAsynchronously];
        
        return;
    }
    
    self.sessionTask = [self createSessionTask]; // by default creates an NSURLSessionDataTask, can be overriden to create another type of NSURLSessionTask
    [self.sessionTask resume];
}

-(BOOL)isFinished
{
    return _finished;
}

-(void)setFinished:(BOOL)finished
{
    // NSOperation overriding is difficult as the KVO key is "isFinished" and not "finished"
    @synchronized(self) {
        [self willChangeValueForKey:@"isFinished"];
        _finished = finished;
        [self didChangeValueForKey:@"isFinished"];
    }
}

-(void)setLocalConfig:(NSURLSessionConfiguration *)localConfig
{
    if([self isExecuting]) {
        [NSException raise:NSInternalInconsistencyException format:@"You should not modify the NetworkOperation localConfig while it's running. It should be set before starting the operation."];
    }
    
    NSURLSessionConfiguration *usedConfig = localConfig;
    if(!localConfig) {
        usedConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    }
    
    _localConfig = usedConfig;
}

-(NSURLSession *)localURLSession
{
    if(!_localURLSession)
    {
        _localURLSession = [NSURLSession sessionWithConfiguration:_localConfig delegate:self delegateQueue:nil]; // as documented in NSURLSession, delegate is retained! so we have to ensure we break the retain cycle later!
    }
    
    return _localURLSession;
}

-(void)setResponseQueue:(dispatch_queue_t)responseQueue
{
    if(responseQueue == nil) {
        _responseQueue = dispatch_get_main_queue();
    }
    else {
        _responseQueue = responseQueue;
    }
}
                    
#pragma mark - Protected, meant to be overriden

-(NSString *)debugDescription
{
    return [self description]; // because it seems NSOperation debugDescription does not call description!!
}

-(NSString *)description
{
    id requestOrURL = self.request ? self.request : self.urlString;
    return [NSString stringWithFormat:@"%@ - URL:%@ - state:%@", [super description], requestOrURL, [self stateDescription]];
}

-(NSString *)stateDescription
{
    if(self.cancelled) return @"cancelled";
    if(self.finished) return @"finished";
    if(self.executing) return @"executing";
    if(self.ready) return @"ready";
    
    return @"unknown";
}

-(BOOL)validateResponse:(NSHTTPURLResponse *)response withError:(NSError **)error
{
    if(self.response.statusCode < 200 || self.response.statusCode > 300)
    {
#if DEBUG
        NSLog(@"%s - status code:%ld (%@) for request (%@) URL:%@",__PRETTY_FUNCTION__,(long)self.response.statusCode, [NSHTTPURLResponse localizedStringForStatusCode:self.response.statusCode], self.request.HTTPMethod, self.request.URL);
#endif
        if(error) {
            *error = [NSError errorWithDomain:@"com.carrafix.CFXNetworkOperation" code:self.response.statusCode/*NSURLErrorBadServerResponse*/ userInfo:@{NSLocalizedDescriptionKey : [NSHTTPURLResponse localizedStringForStatusCode:self.response.statusCode],                                                                                                                                                          NSURLErrorFailingURLErrorKey : self.request.URL,
                }];
        }
        return NO;
    }
    
    // check server Content-Type is allowedMimeTypes not empty
    if(self.allowedMimeTypes.count > 0 && ![self.allowedMimeTypes containsObject:response.MIMEType]) // case sensitivity problem?
    {
        if(error) {
            *error = [NSError errorWithDomain:@"com.carrafix.CFXJSONNetworkOperation" code:NSURLErrorCannotDecodeContentData userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"expected MIME types:%@ but got:'%@'",self.allowedMimeTypes, response.MIMEType], NSURLErrorFailingURLErrorKey : self.request.URL}];
            
            NSLog(@"%s - Content-Type mismatch for WebService request:(%@)%@ - error:%@",__PRETTY_FUNCTION__,self.request.HTTPMethod,[self.request.URL absoluteString],error?*error:@"<nil error>");
        }
        
        return NO;
    }

    
//#if DEBUG
//    NSLog(@"%s - response HTTP headers:%@",__PRETTY_FUNCTION__,response.allHeaderFields);
//#endif
    
    return YES;
}

-(BOOL)processIncomingDataWithError:(NSError **)error
{
    [NSException raise:NSInternalInconsistencyException format:@"You should not call super!"];
    return NO;
}

-(NSMutableURLRequest*)serializeRequestWithMethod:(nonnull NSString *)method urlString:(nonnull NSString *)urlString requestParameters:(NSDictionary<NSString *, NSString *> *)requestParameters error:(NSError **)error
{
    NSAssert(method != nil, @"method must not be nil");
    
    NSURLComponents *urlComponents = [NSURLComponents componentsWithString:urlString];
    if(urlComponents == nil) {
        if(error) {
            *error = [NSError errorWithDomain:@"com.carrafix.CFXNetworkOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Unable to serialize URL with base string:'%@'",urlString]}];
        }

        return nil;
    }
    NSMutableArray *queryItems = [urlComponents.queryItems mutableCopy];
    if(queryItems == nil)
        queryItems = [NSMutableArray array];
    
    __block NSString *invalidKey = nil;
    __block NSString *invalidObj = nil;
    [requestParameters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        NSURLQueryItem *qi = [NSURLQueryItem queryItemWithName:key value:obj];
        if(qi == nil) {
            invalidKey = key;
            invalidObj = obj;
            *stop = YES;
        }
        else {
            [queryItems addObject:qi];
        }
    }];
    
    if([queryItems count] > 0) { // beware adding an empty array adds a ? with no key/value as parameter
        urlComponents.queryItems = queryItems;
    }
    
    if(invalidKey != nil)
    {
        if(error) {
            *error = [NSError errorWithDomain:@"com.carrafix.CFXNetworkOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Unable to serialize URL query parameter:'%@'='%@'",invalidKey, invalidObj]}];
        }
        return nil;
    }
    
    NSURL *url = urlComponents.URL;
    if(url == nil) {
        if(error) {
            *error = [NSError errorWithDomain:@"com.carrafix.CFXNetworkOperation" code:0 userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Unable to serialize URL from URLComponents:%@",urlComponents]}];
        }
        return nil;
    }
    
    // create request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = method;
    
    if(self.body != nil && self.bodyBuilderBlock != nil) {
        [NSException raise:NSInternalInconsistencyException format:@"both body and bodyBuilderBlock properties can't be non nil. Either you give a body or a bodyBuilderBlock, but not both!"];
    }
    
    if(self.body != nil)  {
        
        request.HTTPBody = self.body;

        if(self.body.length > DEFAULT_BODY_LENGTH_GZIP_THRESHOLD && self.gzipBody == YES) {
            // executed on the NSOperation's queue
            request.HTTPBody = [self.body gzippedData];
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        }
    }
    else if(self.bodyBuilderBlock != nil) {
        // executed on the NSOperation's queue
        NSData *builtBody = self.bodyBuilderBlock();
        self.body = builtBody;
        request.HTTPBody = builtBody;
        
        if(builtBody.length > DEFAULT_BODY_LENGTH_GZIP_THRESHOLD && self.gzipBody == YES) {
            // executed on the NSOperation's queue
            request.HTTPBody = [builtBody gzippedData];
            [request setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        }
        
        self.bodyBuilderBlock = nil; // auto nullified after use to avoid possible retain cycles
    }
    
    for(NSString *header in self.additionalHeaders) {
        if(self.gzipBody == YES && [header caseInsensitiveCompare:@"Content-Encoding"] == NSOrderedSame && [self.additionalHeaders[header] caseInsensitiveCompare:@"gzip"] != NSOrderedSame) {
            [NSException raise:NSInternalInconsistencyException format:@"Can't set 'gzipBody' to YES and have an HTTP header 'Content-Encoding' set to another value than 'gzip'!"];
        }
        
        [request setValue:self.additionalHeaders[header] forHTTPHeaderField:header];
    }
    
    return request;
}

-(NSURLSessionTask*)createSessionTask
{
    // by default creates an NSURLSessionDataTask, can be overriden to create another type of NSURLSessionTask
    return [self.localURLSession dataTaskWithRequest:self.request];
}

-(void)callResponseBlockAsynchronously
{
    dispatch_async(self.responseQueue, ^{
        if(self.responseBlock) {
            self.responseBlock(self, self.responseObject, self.error);
            self.responseBlock = nil;
        }
    });
}

#pragma mark - NSURLSession Delegate Methods

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
#warning INSECURE CREDENTIAL USAGE, ACCEPTS ANY CERTIFICATES!
    // AH: this implementation allows unrecognized certificates as, when in development, the server did not have trusted signed certificates.
    // It allows *any* certificate, even insecure ones! so beware!!!
    // TODO: we should use certificate pinning or something like that to secure this correctly.
    completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    self.response = (NSHTTPURLResponse*)response;
    
    if([self isCancelled]) {
        self.finished = YES;
        [_sessionTask cancel];
        
        return;
    }
    
    if(self.response.expectedContentLength != -1) { // AH: expectedContentLength may be -1, whereas the Content-Length header value is > 0 but "incorrect". That's because of gzip compression (knowning the decompressed size of data is impossible before having decompressed it!)
        self.progress.totalUnitCount = self.response.expectedContentLength;
    }
    else {
        self.progress.totalUnitCount = 0;
    }
    
// So strange. Sometimes Apple reports the correct value, sometimes not. Probably too complex to understand because of gzip compression handling 
//#if DEBUG
//    NSLog(@"%s - (%p) expectedContentLength:%lld vs Content-Length:%lld",__PRETTY_FUNCTION__,self,self.response.expectedContentLength,[self.response.allHeaderFields[@"Content-Length"] longLongValue]);
//#endif
    
    
    NSError *error;
    if(![self validateResponse:self.response withError:&error])
    {
        // Apple shitty documentation! calling completionHandler(NSURLSessionResponseCancel) in fact turns the error information to "cancelled" so we have lost the real error....
        completionHandler(NSURLSessionResponseCancel); // same as calling -cancel on the task, so -(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error will be called!
        self.error = error;
        self.finished = YES;
        
        // NOW HANDLED IN -(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
        //[self callResponseBlockAsynchronously];
        
        return;
    }
    
    completionHandler(NSURLSessionResponseAllow);
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    if([self isCancelled]) {
        self.finished = YES;
        [_sessionTask cancel];
        
        return;
    }
    
    // There may be a problem here because the data is already decompressed, when what we wanted is the compressed length...
    if(dataTask.countOfBytesExpectedToReceive != -1) { // AH: countOfBytesExpectedToReceive may be -1, whereas the Content-Length header value is > 0 (but may be incorrect too). That's because of gzip compression (knowning the decompressed size of data is impossible before having decompressed it!)
        self.progress.totalUnitCount = dataTask.countOfBytesExpectedToReceive; // value has already been set in didReceiveResponse: anyway
    }
    
    if(_incomingData == nil) {
        self.incomingData = [NSMutableData data];
    }
    [_incomingData appendData:data];
    
    if(self.progress.totalUnitCount > 0) {
        self.progress.completedUnitCount = dataTask.countOfBytesReceived; // is the decompressed data length... Apple does not provide us with the real received data length...
    }
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if([self isCancelled]) {
        self.finished = YES;
        [_sessionTask cancel];
        
        return;
    }
    
    if(error)
    {
        if([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) { // special handling for *task* (not operation!) cancellation using completionHandler(NSURLSessionResponseCancel). The error may already be set and the *real* reason for cancellation is already set, so do not replace it with Apple "cancelled" error! The operation is already finished at this point
            if(self.error == nil) {
                self.error = error;
            }
        }
        else {
            self.error = error;
            self.finished = YES;
        }
        
        NSLog(@"%s - URLSession failed with error:%@ for WebService request:(%@)%@",__PRETTY_FUNCTION__,error,self.request.HTTPMethod,[self.request.URL absoluteString]);
        
        // breaks the retain cycles!
        [_localURLSession invalidateAndCancel];
        _localURLSession = nil;
        _sessionTask = nil;
        
        [self callResponseBlockAsynchronously];
        
        return;
    }
    
    NSError *dataProcessingError;
    // AH: note that it can be valid to have nil incomingData (but HTTP response status code set to 200) if the webservice does not response any "value" (having a status code 200 may mean "OK" or "true" to the request)
    if(self.incomingData != nil && [self processIncomingDataWithError:&dataProcessingError] == NO) {
        self.error = dataProcessingError;
        self.finished = YES;
        if(self.progress.totalUnitCount == 0) { // if the task didn't achieve to get the real total unit count, the progress is indeterminate and we don't like that, so do as if it completed
            self.progress.totalUnitCount = 1;
        }
        self.progress.completedUnitCount = self.progress.totalUnitCount;
        
        // breaks the retain cycles!
        [_localURLSession invalidateAndCancel];
        _localURLSession = nil;
        _sessionTask = nil;
        
        [self callResponseBlockAsynchronously];
        
        return;
    }
    
    // normal termination
    self.finished = YES;
    if(self.progress.totalUnitCount == 0) { // if the task didn't achieve to get the real total unit count, the progress is indeterminate and we don't like that, so do as if it completed
        self.progress.totalUnitCount = 1;
    }
    self.progress.completedUnitCount = self.progress.totalUnitCount;
    
    // breaks the retain cycles!
    [_localURLSession invalidateAndCancel];
    _localURLSession = nil;
    _sessionTask = nil;
    
    [self callResponseBlockAsynchronously];
}

@end

