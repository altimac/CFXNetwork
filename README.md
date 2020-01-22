# CFXNetwork
A minimalist, but easy way to do client HTTP network operations and encode/decode (JSON) bodies (also easy to extend to support XML, Plist etc...) on Apple plateforms.

The main idea is that the base class inherits NSOperation. It allows leveraging this very cool API to handle dependencies, prioritization, cancelling, parallelism or serial, queue/thread control etc...

Like every iOS developer, I used to use AFNetwork (now "AlamoFire"). But since many years know I just find all those layers simply bloatware, complex and cumbersome. Reading their documentation is just too long when what you need is just an HTTP client. I'm simply amazed there even is a layer above AlamoFire (Moya) that is successful... Its Cocoapods/Carthage/SPM documentation *alone* is bigger than this project entire code 🤣
I hate loosing control and I can't debug those helpers when a problem arise.
My solution is a small, minimalist code inspired by Marcus Zarra on his blog: http://www.cimgf.com/2016/01/28/a-modern-network-operation/

Usage/Example :
This pseudo code suppose you have a completion block to call at the end of the async request...

```
CFXJSONNetworkOperation *mainOp = [[CFXJSONNetworkOperation alloc] initWithMethod:@"POST" urlString:@"https://meta.herdly.cloud/servers.json" parameters:nil];
    
    // completely optional, but shown as a cool option for the README
    mainOp.localConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData; // we can specifically ask URL loading system not to use cache for this request. There are many other settings you can look at, but I like the minimal setup to just work :)
    
    mainOp.body = [NSJSONSerialization dataWithJSONObject:@{@"argument1" : @(1234),
                                                        @"username" : @"me",
                                                        @"password" : @"myPazzw0rd"} options:0 error:nil];

    mainOp.responseBlock = ^(CFXNetworkOperation *operation, id responseObject, NSError *error) {        
        // responseObject is a JSON unmarshaled object, aka an NSDictionary*, NSArray*, NSNumber* or nothin
        if(!responseObject) {
            if(completionBlock) dispatch_async(self.completionQueue,^{
                    completionBlock(nil, operation); // typically call the completion block when the request failed, the operation will contain the HTTP error
                });
            
            return;
        }
                
        credential = [responseObject objectForKey:@"credential"]; // let's say the webservice returned a token credential in the body     
    
        if(completionBlock) dispatch_async(self.completionQueue,^{
                completionBlock(credential, operation); // typically call the completion block when the request succeed
        });
    };
    
  [[NSOperationQueue mainQueue] addOperation:mainOp]; // starts the request asynchronously
