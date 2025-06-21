//
//  TLTagLibFile.h
//  TrackList
//
//  Created by Pavel Fomin on 21.06.2025.
//

#ifndef TLTagLibFile_h
#define TLTagLibFile_h


#endif /* TLTagLibFile_h */

#import <Foundation/Foundation.h>

@class TLTagLibFileResult;

NS_ASSUME_NONNULL_BEGIN

@interface TLTagLibFileResult : NSObject
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *artist;
@property (nonatomic, copy, nullable) NSString *album;
@property (nonatomic, copy, nullable) NSString *genre;
@property (nonatomic, copy, nullable) NSString *comment;
@property (nonatomic, strong, nullable) NSData *artworkData;
@end

/// Добавляем `FOUNDATION_EXPORT` — иначе Swift не видит сигнатуру
FOUNDATION_EXPORT TLTagLibFileResult *_Nullable _readMetadata(NSString *filePath);

NS_ASSUME_NONNULL_END
