//
//  TLTagLibFile.m
//  TrackList
//
//  Created by Pavel Fomin on 21.06.2025.
//

#import <Foundation/Foundation.h>
#import "TLTagLibFile.h"
#import <tag_c/tag_c.h>

@implementation TLTagLibFileResult
@end

TLTagLibFileResult *_readMetadata(NSString *filePath) {
    const char *cPath = [filePath fileSystemRepresentation];
    TagLib_File *file = taglib_file_new(cPath);
    if (!file) return nil;

    TagLib_Tag *tag = taglib_file_tag(file);
    if (!tag) {
        taglib_file_free(file);
        return nil;
    }

    TLTagLibFileResult *result = [TLTagLibFileResult new];

    char *title = taglib_tag_title(tag);
    char *artist = taglib_tag_artist(tag);
    char *album = taglib_tag_album(tag);
    char *genre = taglib_tag_genre(tag);
    char *comment = taglib_tag_comment(tag);

    if (title) result.title = [NSString stringWithUTF8String:title];
    if (artist) result.artist = [NSString stringWithUTF8String:artist];
    if (album) result.album = [NSString stringWithUTF8String:album];
    if (genre) result.genre = [NSString stringWithUTF8String:genre];
    if (comment) result.comment = [NSString stringWithUTF8String:comment];
    
    TagLib_Complex_Property_Attribute ***props = taglib_complex_property_get(file, "PICTURE");
    if (props) {
        TagLib_Complex_Property_Picture_Data picture = {0}; // stack-allocated
        taglib_picture_from_complex_property(props, &picture);
        if (picture.data && picture.size > 0) {
            NSData *imageData = [NSData dataWithBytes:picture.data length:picture.size];
            result.artworkData = imageData;
        }
        taglib_complex_property_free(props); // освобождаем
    }

    taglib_tag_free_strings(); // важно!
    taglib_file_free(file);
    return result;
    
}
