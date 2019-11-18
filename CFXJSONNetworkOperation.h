//
//  CFXJSONNetworkOperation.h
//  Carrafix
//
//  Created by Aurélien Hugelé on 20/04/16.
//  Copyright © 2016 Carrafix. All rights reserved.
//

#import "CFXNetworkOperation.h"

@interface CFXJSONNetworkOperation : CFXNetworkOperation

@property(nullable, readonly) NSData* rawResponseObject; // mainly for debugging, returns incomingData (as immutable NSData*).

@end
