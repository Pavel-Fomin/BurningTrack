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
#import <tag_c/tag_c.h>

// MARK: - Реализация класса результата

@implementation TLTagLibFileResult
// Пустая реализация — все свойства определены в заголовочном файле

@end

// MARK: - Главная функция чтения тегов

// Читает метаданные из указанного аудиофайла с помощью TagLib
// Возвращает объект TLTagLibFileResult или nil при ошибке
TLTagLibFileResult *_readMetadata(NSString *filePath) {
    
    // Преобразуем путь из NSString в C-строку
    const char *cPath = [filePath fileSystemRepresentation];
    
    // Открываем файл через TagLib
    TagLib_File *file = taglib_file_new(cPath);
    if (!file) return nil;
    
    // Получаем теги
    TagLib_Tag *tag = taglib_file_tag(file);
    if (!tag) {
        taglib_file_free(file);
        return nil;
    }
    
    // Создаём объект результата
    TLTagLibFileResult *result = [TLTagLibFileResult new];
    
    // Считываем строковые поля
    char *title = taglib_tag_title(tag);
    char *artist = taglib_tag_artist(tag);
    char *album = taglib_tag_album(tag);
    char *genre = taglib_tag_genre(tag);
    char *comment = taglib_tag_comment(tag);

    // Преобразуем в NSString и сохраняем
    if (title) result.title = [NSString stringWithUTF8String:title];
    if (artist) result.artist = [NSString stringWithUTF8String:artist];
    if (album) result.album = [NSString stringWithUTF8String:album];
    if (genre) result.genre = [NSString stringWithUTF8String:genre];
    if (comment) result.comment = [NSString stringWithUTF8String:comment];
    
    // MARK: - Обработка обложки (если есть)
    
    // Получаем картинку из complex property "PICTURE"
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
    
    // MARK: - Очистка ресурсов

    taglib_tag_free_strings(); /// Обязательно: очищает внутренние строки TagLib
    taglib_file_free(file);    /// Освобождаем файл
    return result;
    
}
