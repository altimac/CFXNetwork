//
//  CFXJSONNetworkOperation.h
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 2016 Carrafix. All rights reserved.
//
// This class is dedicated to HTTP requests with decoding/encoding of JSON bodies

#import "CFXNetworkOperation.h"

@interface CFXJSONNetworkOperation : CFXNetworkOperation

@property(nullable, readonly) NSData* rawResponseObject; // mainly for debugging, returns incomingData (as immutable NSData*).

@end
