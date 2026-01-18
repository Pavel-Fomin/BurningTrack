//
//  TLTagLibFile.m
//  TrackList
//
//  Реализация обёртки для чтения тегов через TagLib (C API)
//  Используется в Swift через Bridging Header
//
//  Created by Pavel Fomin on 21.06.2025.
//

#import <Foundation/Foundation.h>
#import "TLTagLibFile.h"
#import <tag_c.h>


static inline void TLTagLibSetup(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taglib_set_string_management_enabled(false);
    });
}


// MARK: - Реализация класса результата

@implementation TLTagLibFileResult
// Пустая реализация — все свойства определены в заголовочном файле

@end


// MARK: - Главная функция чтения тегов

// Читает метаданные из указанного аудиофайла с помощью TagLib
// Возвращает объект TLTagLibFileResult или nil при ошибке
TLTagLibFileResult *_readMetadata(NSString *filePath) {
    
    TLTagLibSetup();
    
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

    if (title && strlen(title) > 0) result.title = [NSString stringWithUTF8String:title];
    if (artist && strlen(artist) > 0) result.artist = [NSString stringWithUTF8String:artist];
    if (album && strlen(album) > 0) result.album = [NSString stringWithUTF8String:album];
    if (genre && strlen(genre) > 0) result.genre = [NSString stringWithUTF8String:genre];
    if (comment && strlen(comment) > 0) result.comment = [NSString stringWithUTF8String:comment];

    // Обрабатываем обложку ДО освобождения файла
    TagLib_Complex_Property_Attribute ***props = taglib_complex_property_get(file, "PICTURE");
    if (props) {
        TagLib_Complex_Property_Picture_Data picture = {0};
        taglib_picture_from_complex_property(props, &picture);

        if (picture.data && picture.size > 0) {
            void *copy = malloc(picture.size);
            if (copy) {
                memcpy(copy, picture.data, picture.size);
                NSData *imageData = [NSData dataWithBytesNoCopy:copy length:picture.size freeWhenDone:YES];
                result.artworkData = imageData;
            }
        }
        taglib_complex_property_free(props);
    }

    // Очистка
    // taglib_tag_free_strings(); // больше не вызываем
    taglib_file_free(file);

    return result;
}
