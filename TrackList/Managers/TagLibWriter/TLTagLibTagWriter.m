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

TLTagWriteResult *_Nonnull _writeBasicTags(

    NSString *filePath,

    TLTagFieldAction titleAction,
    NSString *_Nullable title,

    TLTagFieldAction artistAction,
    NSString *_Nullable artist,

    TLTagFieldAction albumAction,
    NSString *_Nullable album,

    TLTagFieldAction genreAction,
    NSString *_Nullable genre,

    TLTagFieldAction commentAction,
    NSString *_Nullable comment,

    TLTagFieldAction publisherAction,
    NSString *_Nullable publisher,

    TLTagFieldAction yearAction,
    NSNumber *_Nullable year,

    TLTagFieldAction trackNumberAction,
    NSNumber *_Nullable trackNumber,

    TLTagFieldAction bpmAction,
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

    // MARK: - Базовые текстовые теги

    switch (titleAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_title(tag, title.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_title(tag, "");
            break;
    }

    switch (artistAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_artist(tag, artist.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_artist(tag, "");
            break;
    }

    switch (albumAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_album(tag, album.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_album(tag, "");
            break;
    }

    switch (genreAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_genre(tag, genre.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_genre(tag, "");
            break;
    }

    switch (commentAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_comment(tag, comment.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_comment(tag, "");
            break;
    }

    // MARK: - Издатель / лейбл

    switch (publisherAction) {
        case TLTagFieldActionUnchanged:
            break;

        case TLTagFieldActionSet:
            taglib_property_set(file, "PUBLISHER", publisher.UTF8String);
            taglib_property_set(file, "LABEL", NULL);
            taglib_property_set(file, "ORGANIZATION", NULL);
            break;

        case TLTagFieldActionClear:
            taglib_property_set(file, "PUBLISHER", NULL);
            taglib_property_set(file, "LABEL", NULL);
            taglib_property_set(file, "ORGANIZATION", NULL);
            break;
    }

    // MARK: - Числовые теги

    switch (yearAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_year(tag, year.unsignedIntValue);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_year(tag, 0);
            break;
    }

    switch (trackNumberAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_tag_set_track(tag, trackNumber.unsignedIntValue);
            break;
        case TLTagFieldActionClear:
            taglib_tag_set_track(tag, 0);
            break;
    }

    switch (bpmAction) {
        case TLTagFieldActionUnchanged:
            break;
        case TLTagFieldActionSet:
            taglib_property_set(file, "BPM", bpm.stringValue.UTF8String);
            break;
        case TLTagFieldActionClear:
            taglib_property_set(file, "BPM", NULL);
            break;
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
