//
//  TrackList-Bridging-Header.h
//  TrackList
//
//  Используется для подключения Objective-C/С++ кода в Swift
//
//  Created by Pavel Fomin on 21.06.2025.
//

// Подключение обёртки для чтения TagLib
#import "TLTagLibFile.h"

// Подключение обёртки для записи TagLib (только текстовые тэги)
#import "TLTagLibTagWriter.h"
