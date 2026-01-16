//
//  TrackList-Bridging-Header.h
//  TrackList
//
//  Используется для подключения Objective-C/С++ кода в Swift
//
//  Created by Pavel Fomin on 21.06.2025.
//

// Подключение C-интерфейса библиотеки TagLib
#import <tag_c.h>

// Подключение обёртки над TagLib
#import "TLTagLibFile.h"

#import "TLTagLibTagWriter.h"
