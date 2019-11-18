# CFXNetwork
A minimalist, but easy way to do client HTTP network operations and encode/decode bodies (easy to extend to anything else than JSON)

The main idea is that the base class inherits NSOperation. It allows leverage this very cool API to handle dependencies, prioritization, cancelling, queue/thread control etc...


Usage/Example :
This pseudo code suppose you have a completion block to call at the end of the async request...

```
CFXJSONNetworkOperation *mainOp = [[HDYNetworkOperation alloc] initWithMethod:@"GET" urlString:@"https://meta.herdly.cloud/servers.json" parameters:nil];
    
    // completely optional, but shown as a cool option for the README
    mainOp.localConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // we can specifically ask URL loading system not to use cache for this request. There are many other settings you can look at, but I like the minimal setup to just work :)
    
    mainOp.body = [NSJSONSerialization dataWithJSONObject:@{@"argument1" : @(1234),
                                                        @"username" : @"me",
                                                        @"password" : @"myPazzw0rd"} options:0 error:nil];

    mainOp.responseBlock = ^(CFXNetworkOperation *operation, id responseObject, NSError *error) {
        
        // responseObject is a JSON unmarshaled object, aka an NSDictionary*, NSArray*, NSNumber* or nothin
        if(!responseObject) {
            if(completionBlock)
                dispatch_async(self.completionQueue,^{
                    completionBlock(nil, operation); // typically call the completion block when the request failed, the operation will contain the HTTP error
                });
            
            return;
        }
                
        credential = [responseObject objectForKey:@"credential"]; // let's say the webservice returned a token credential in the body     
    
        if(completionBlock)
            dispatch_async(self.completionQueue,^{
                completionBlock(credential, operation); // typically call the completion block when the request succeed
            });
    };
    
  [[NSOperationQueue mainQueue] addOperation:mainOp]; // starts the request asynchronously
