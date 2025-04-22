//
//  TagReader.m
//  TrackList
//
//  Created by Pavel Fomin on 21.04.2025.
//

#import <Foundation/Foundation.h>
#import "TagReader.h"

#include "fileref.h"
#include "tag.h"
#include "toolkit/tstring.h"

using namespace TagLib;

@implementation TagReader

+ (NSDictionary *)readTagsFromFileAtPath:(NSString *)filePath {
    NSLog(@"[TagReader] Called with path: %@", filePath);

    const char *cPath = [filePath UTF8String];
    FileRef file(cPath);

    if (!file.isNull() && file.tag()) {
        Tag *tag = file.tag();
        NSString *title = [NSString stringWithUTF8String:tag->title().toCString(true)];
        NSString *artist = [NSString stringWithUTF8String:tag->artist().toCString(true)];

        NSLog(@"[TagReader] Title: %@", title);
        NSLog(@"[TagReader] Artist: %@", artist);

        return @{
            @"title": title ?: @"",
            @"artist": artist ?: @""
        };
    }

    NSLog(@"[TagReader] Failed to read tags");
    return @{};
}

@end
