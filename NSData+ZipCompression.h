//
//  NSData+ZipCompression.h
//  CFXKit
//
//  Created by Aurélien Hugelé on 18/11/2019.
//  Copyright © 2019 Carrafix. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//  copied from https://github.com/nicklockwood/GZIP   check regularly if code is updated. Should be quite safe as Nick Lockwood's code is generally very good.
@interface NSData (ZipCompression)

- (nullable NSData *)gzippedDataWithCompressionLevel:(float)level;
- (nullable NSData *)gzippedData;
- (nullable NSData *)gunzippedData;
- (BOOL)isGzippedData;

@end

NS_ASSUME_NONNULL_END
