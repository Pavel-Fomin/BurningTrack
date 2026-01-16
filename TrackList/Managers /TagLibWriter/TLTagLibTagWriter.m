//
//  TLTagLibTagWriter.m
//  TrackList
//
//  Реализация записи тегов через TagLib C API
//
//  Created by PavelFomin on 16.01.2026.
//


#import "TLTagLibTagWriter.h"
#import <tag_c.h>

static inline void TLTagLibSetup(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taglib_set_string_management_enabled(false);
    });
}

@implementation TLTagWriteResult
@end

TLTagWriteResult *_writeBasicTags(
    NSString *filePath,
    NSString *_Nullable title,
    NSString *_Nullable artist,
    NSString *_Nullable album,
    NSString *_Nullable genre,
    NSString *_Nullable comment,
    NSNumber *_Nullable year,
    NSNumber *_Nullable trackNumber,
    NSNumber *_Nullable bpm,
    TLArtworkAction artworkAction,
    NSData *_Nullable artworkData,
    NSString *_Nullable artworkMime
) {
    TLTagLibSetup();

    TLTagWriteResult *result = [TLTagWriteResult new];
    result.status = TLTagWriteStatusUnknown;

    const char *cPath = [filePath fileSystemRepresentation];
    if (!cPath) {
        result.status = TLTagWriteStatusFileNotFound;
        return result;
    }

    TagLib_File *file = taglib_file_new(cPath);
    if (!file) {
        result.status = TLTagWriteStatusFileNotFound;
        return result;
    }

    TagLib_Tag *tag = taglib_file_tag(file);
    if (!tag) {
        taglib_file_free(file);
        result.status = TLTagWriteStatusUnsupportedFormat;
        return result;
    }

    // Запись текстовых полей (nil → не трогаем)
    if (title) {
        taglib_tag_set_title(tag, title.UTF8String);
    }
    if (artist) {
        taglib_tag_set_artist(tag, artist.UTF8String);
    }
    if (album) {
        taglib_tag_set_album(tag, album.UTF8String);
    }
    if (genre) {
        taglib_tag_set_genre(tag, genre.UTF8String);
    }
    if (comment) {
        taglib_tag_set_comment(tag, comment.UTF8String);
    }

    // Числовые поля
    if (year) {
        taglib_tag_set_year(tag, year.intValue);
    }
    if (trackNumber) {
        taglib_tag_set_track(tag, trackNumber.intValue);
    }

    // BPM не входит в базовый TagLib_Tag
    // Сохраняем через complex property (best effort)
    if (bpm) {
        taglib_property_set(file, "BPM", bpm.stringValue.UTF8String);
    }
    

    // Сохраняем файл
    if (!taglib_file_save(file)) {
        taglib_file_free(file);
        result.status = TLTagWriteStatusSaveFailed;
        result.details = @"taglib_file_save вернул false";
        return result;
    }

    taglib_file_free(file);

    result.status = TLTagWriteStatusOk;
    return result;
}
