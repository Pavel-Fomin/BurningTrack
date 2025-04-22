//
//  TagReader.h
//  TrackList
//
//  Created by Pavel Fomin on 21.04.2025.
//
#import <Foundation/Foundation.h>
#import <TagLib/fileref.h>
#import <taglib/tag.h>

@interface TagReader : NSObject
+ (NSDictionary *)readTagsFromFileAtPath:(NSString *)filePath;
@end
