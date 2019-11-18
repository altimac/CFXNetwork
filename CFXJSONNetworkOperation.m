//
//  CFXJSONNetworkOperation.m
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 2016 Carrafix. All rights reserved.
//

#import "CFXJSONNetworkOperation.h"
#import "CFXNetworkOperation_private.h"

@implementation CFXJSONNetworkOperation

-(instancetype)initWithMethod:(NSString *)method urlString:(NSString *)urlString parameters:(NSDictionary<NSString *,NSString *> *)requestParameters
{
    self = [super initWithMethod:method urlString:urlString parameters:requestParameters];
    if(self) {
        [self.allowedMimeTypes addObject:@"application/json"];
        [self.allowedMimeTypes addObject:@"text/json"];
    }
    
    return self;
}

-(BOOL)processIncomingDataWithError:(NSError * _Nullable __autoreleasing *)error
{
    // do not call super as it is abstract class
    
    if([self.incomingData length] == 0 && self.allowEmptyResponse == YES) {
        
        return YES;
    }
    
    NSError *jsonError;
    self.responseObject = [NSJSONSerialization JSONObjectWithData:self.incomingData options:NSJSONReadingAllowFragments error:&jsonError];
    if(!self.responseObject)
    {
        if(error) *error = jsonError;
        NSLog(@"%s - NSJSONSerialization error:%@ when parsing:\n%@ for WebService request:(%@)%@",__PRETTY_FUNCTION__,jsonError,[[NSString alloc] initWithData:self.incomingData encoding:NSUTF8StringEncoding],self.request.HTTPMethod,[self.request.URL absoluteString]);
    }
    
    return (self.responseObject != nil);
}

// mainly for debugging
-(NSData *)rawResponseObject
{
    return [NSData dataWithData:self.incomingData];
}

@end
