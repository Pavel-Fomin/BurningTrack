//
//  TLTagLibFile.h
//  TrackList
//
//  Заголовочный файл обёртки для чтения метаданных из аудиофайлов через TagLib
//  Экспортирует интерфейс, который будет доступен из Swift через Bridging Header
//
//  Created by Pavel Fomin on 21.06.2025.
//

#ifndef TLTagLibFile_h
#define TLTagLibFile_h

#endif /* TLTagLibFile_h */

#import <Foundation/Foundation.h>

// MARK: - Объявление модели результата

// Класс-обёртка для возвращаемых метаданных трека.
// Используется при чтении тегов с помощью функции _readMetadata.
@class TLTagLibFileResult;

NS_ASSUME_NONNULL_BEGIN

@interface TLTagLibFileResult : NSObject

// Название трека
@property (nonatomic, copy, nullable) NSString *title;

// Исполнитель
@property (nonatomic, copy, nullable) NSString *artist;

// Альбом
@property (nonatomic, copy, nullable) NSString *album;

// Жанр
@property (nonatomic, copy, nullable) NSString *genre;

// Комментарий
@property (nonatomic, copy, nullable) NSString *comment;

// Двоичные данные изображения обложки (если есть)
@property (nonatomic, strong, nullable) NSData *artworkData;
@end

// MARK: - Экспорт функции в Swift

// Основная функция чтения тегов через TagLib.
// Принимает путь к файлу, возвращает объект TLTagLibFileResult.
// Экспортирована через `FOUNDATION_EXPORT` для доступа из Swift.
FOUNDATION_EXPORT TLTagLibFileResult *_Nullable _readMetadata(NSString *filePath);

NS_ASSUME_NONNULL_END
