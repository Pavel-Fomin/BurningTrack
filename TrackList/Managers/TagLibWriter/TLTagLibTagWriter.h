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

typedef NS_ENUM(NSInteger, TLTagFieldAction) {

    /// Поле не менять
    TLTagFieldActionUnchanged = 0,

    /// Записать новое значение
    TLTagFieldActionSet,

    /// Очистить поле
    TLTagFieldActionClear
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
);

NS_ASSUME_NONNULL_END
