//
//  TLTagLibTagWriter.h
//  TrackList
//
//  Obj-C обёртка для записи тегов через TagLib C API.
//  НЕ содержит Swift, UI и логики доступа к файлам.
//
//  Created by PavelFomin on 16.01.2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Статус результата записи тегов
typedef NS_ENUM(NSInteger, TLTagWriteStatus) {
    /// Успешно
    TLTagWriteStatusOk = 0,

    /// Файл не найден или не удалось открыть
    TLTagWriteStatusFileNotFound,

    /// Файл доступен только для чтения
    TLTagWriteStatusFileNotWritable,

    /// Формат не поддерживается
    TLTagWriteStatusUnsupportedFormat,

    /// Ошибка сохранения
    TLTagWriteStatusSaveFailed,

    /// Неизвестная ошибка
    TLTagWriteStatusUnknown
};

typedef NS_ENUM(NSInteger, TLArtworkAction) {
    TLArtworkActionNone = 0,
    TLArtworkActionRemove,
    TLArtworkActionSet
};

/// Результат записи тегов
@interface TLTagWriteResult : NSObject

@property (nonatomic, assign) TLTagWriteStatus status;
@property (nonatomic, copy, nullable) NSString *details;

@end

/// Записывает базовые текстовые теги в аудиофайл.
/// Все параметры optional:
/// - nil → поле не изменяется
FOUNDATION_EXPORT TLTagWriteResult *_Nonnull _writeBasicTags(
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
);

NS_ASSUME_NONNULL_END
