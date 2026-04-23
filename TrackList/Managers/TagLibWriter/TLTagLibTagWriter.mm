//
//  TLTagLibTagWriter.mm
//  TrackList
//
//  Запись тегов через TagLib C++
//
//  Created by PavelFomin on 22.04.2026.
//

#import "TLTagLibTagWriter.h"

#include <fileref.h>
#include <tag.h>
#include <tstring.h>
#include <tpropertymap.h>

#include <mpeg/mpegfile.h>
#include <mpeg/id3v2/id3v2tag.h>
#include <mpeg/id3v2/frames/attachedpictureframe.h>

#include <flac/flacfile.h>
#include <flac/flacpicture.h>

#include <ogg/xiphcomment.h>
#include <ogg/vorbis/vorbisfile.h>
#include <ogg/opus/opusfile.h>

static TagLib::String TLStringFromNSString(NSString *string) {
    if (!string) {return TagLib::String();}
    return TagLib::String([string UTF8String], TagLib::String::UTF8);
}

static TagLib::ByteVector TLByteVectorFromNSData(NSData *data) {
    if (!data || data.length == 0) {return TagLib::ByteVector();}
    return TagLib::ByteVector((const char *)data.bytes, (unsigned int)data.length);
}

static void TLApplyStringField(
    TLTagFieldAction action,
    NSString *_Nullable value,
    void (^setter)(const TagLib::String &)
) {
    switch (action) {
        case TLTagFieldActionUnchanged:
            break;

        case TLTagFieldActionSet:
            setter(TLStringFromNSString(value ?: @""));
            break;

        case TLTagFieldActionClear:
            setter(TagLib::String());
            break;
    }
}

static void TLApplyUnsignedField(
    TLTagFieldAction action,
    NSNumber *_Nullable value,
    void (^setter)(unsigned int)
) {
    switch (action) {
        case TLTagFieldActionUnchanged:
            break;

        case TLTagFieldActionSet:
            setter((unsigned int)[value unsignedIntValue]);
            break;

        case TLTagFieldActionClear:
            setter(0);
            break;
    }
}

static void TLSetFirstPropertyValue(
    TagLib::PropertyMap &properties,
    const char *key,
    TLTagFieldAction action,
    NSString *_Nullable value
) {
    switch (action) {
        case TLTagFieldActionUnchanged:
            break;

        case TLTagFieldActionSet: {
            TagLib::StringList list;
            list.append(TLStringFromNSString(value ?: @""));
            properties.replace(key, list);
            break;
        }

        case TLTagFieldActionClear:
            properties.erase(key);
            break;
    }
}

// MARK: - Artwork helpers

static BOOL TLApplyArtworkToMP3(
    TagLib::MPEG::File *file,
    TLArtworkAction artworkAction,
    NSData *_Nullable artworkData,
    NSString *_Nullable artworkMime
) {
    if (!file) {return NO;}

    TagLib::ID3v2::Tag *tag = file->ID3v2Tag(true);
    if (!tag) {return NO;}

    // Удаляем все старые APIC-кадры.
    TagLib::ID3v2::FrameList frames = tag->frameListMap()["APIC"];
    for (auto it = frames.begin(); it != frames.end(); ++it) {
        tag->removeFrame(*it, true);
    }

    if (artworkAction == TLArtworkActionSet) {
        TagLib::ByteVector pictureData = TLByteVectorFromNSData(artworkData);
        if (pictureData.isEmpty()) {return NO;}

        auto *frame = new TagLib::ID3v2::AttachedPictureFrame;
        frame->setType(TagLib::ID3v2::AttachedPictureFrame::FrontCover);
        frame->setMimeType(TLStringFromNSString(artworkMime ?: @"image/jpeg"));
        frame->setPicture(pictureData);
        tag->addFrame(frame);
    }

    return true;
}

static BOOL TLApplyArtworkToFLAC(
    TagLib::FLAC::File *file,
    TLArtworkAction artworkAction,
    NSData *_Nullable artworkData,
    NSString *_Nullable artworkMime
) {
    if (!file) {return NO;}

    file->removePictures();

    if (artworkAction == TLArtworkActionSet) {
        TagLib::ByteVector pictureData = TLByteVectorFromNSData(artworkData);
        if (pictureData.isEmpty()) {return NO;}

        auto *picture = new TagLib::FLAC::Picture;
        picture->setType(TagLib::FLAC::Picture::FrontCover);
        picture->setMimeType(TLStringFromNSString(artworkMime ?: @"image/jpeg"));
        picture->setData(pictureData);
        file->addPicture(picture);
    }

    return true;
}

static BOOL TLApplyArtworkToXiph(
    TagLib::Ogg::XiphComment *tag,
    TLArtworkAction artworkAction,
    NSData *_Nullable artworkData,
    NSString *_Nullable artworkMime
) {
    if (!tag) {return NO;}

    tag->removeAllPictures();

    if (artworkAction == TLArtworkActionSet) {
        TagLib::ByteVector pictureData = TLByteVectorFromNSData(artworkData);
        if (pictureData.isEmpty()) {return NO;}

        auto *picture = new TagLib::FLAC::Picture;
        picture->setType(TagLib::FLAC::Picture::FrontCover);
        picture->setMimeType(TLStringFromNSString(artworkMime ?: @"image/jpeg"));
        picture->setData(pictureData);
        tag->addPicture(picture);
    }

    return true;
}

static BOOL TLApplyArtwork(
    TagLib::FileRef &fileRef,
    TLArtworkAction artworkAction,
    NSData *_Nullable artworkData,
    NSString *_Nullable artworkMime
) {
    if (artworkAction == TLArtworkActionNone) {return true;}

    TagLib::File *baseFile = fileRef.file();
    if (!baseFile) {return NO;}

    if (auto *mp3File = dynamic_cast<TagLib::MPEG::File *>(baseFile)) {
        return TLApplyArtworkToMP3(mp3File, artworkAction, artworkData, artworkMime);
    }

    if (auto *flacFile = dynamic_cast<TagLib::FLAC::File *>(baseFile)) {
        return TLApplyArtworkToFLAC(flacFile, artworkAction, artworkData, artworkMime);
    }

    if (auto *vorbisFile = dynamic_cast<TagLib::Ogg::Vorbis::File *>(baseFile)) {
        return TLApplyArtworkToXiph(vorbisFile->tag(), artworkAction, artworkData, artworkMime);
    }

    if (auto *opusFile = dynamic_cast<TagLib::Ogg::Opus::File *>(baseFile)) {
        return TLApplyArtworkToXiph(opusFile->tag(), artworkAction, artworkData, artworkMime);
    }

    return NO;
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
    TLTagWriteResult *result = [TLTagWriteResult new];
    result.status = TLTagWriteStatusUnknown;

    const char *cPath = [filePath fileSystemRepresentation];
    if (!cPath) {
        result.status = TLTagWriteStatusFileNotFound;
        return result;
    }

    TagLib::FileRef fileRef(cPath);
    if (fileRef.isNull()) {
        result.status = TLTagWriteStatusFileNotFound;
        return result;
    }

    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {
        result.status = TLTagWriteStatusUnsupportedFormat;
        return result;
    }

    // MARK: - Базовые строковые теги

    TLApplyStringField(titleAction, title, ^(const TagLib::String &value) {
        tag->setTitle(value);
    });

    TLApplyStringField(artistAction, artist, ^(const TagLib::String &value) {
        tag->setArtist(value);
    });

    TLApplyStringField(albumAction, album, ^(const TagLib::String &value) {
        tag->setAlbum(value);
    });

    TLApplyStringField(genreAction, genre, ^(const TagLib::String &value) {
        tag->setGenre(value);
    });

    TLApplyStringField(commentAction, comment, ^(const TagLib::String &value) {
        tag->setComment(value);
    });

    // MARK: - Числовые теги

    TLApplyUnsignedField(yearAction, year, ^(unsigned int value) {
        tag->setYear(value);
    });

    TLApplyUnsignedField(trackNumberAction, trackNumber, ^(unsigned int value) {
        tag->setTrack(value);
    });

    // MARK: - PropertyMap поля

    TagLib::File *baseFile = fileRef.file();
    if (baseFile) {
        TagLib::PropertyMap properties = baseFile->properties();

        // Издатель / лейбл
        TLSetFirstPropertyValue(properties, "PUBLISHER", publisherAction, publisher);
        if (publisherAction != TLTagFieldActionUnchanged) {
            properties.erase("LABEL");
            properties.erase("ORGANIZATION");
        }

        // BPM
        TLSetFirstPropertyValue(properties, "BPM", bpmAction, bpm ? [bpm stringValue] : nil);

        baseFile->setProperties(properties);
    }

    // MARK: - Artwork

    if (!TLApplyArtwork(fileRef, artworkAction, artworkData, artworkMime)) {
        if (artworkAction != TLArtworkActionNone) {
            result.status = TLTagWriteStatusUnsupportedFormat;
            result.details = @"Artwork writing is not supported for this format";
            return result;
        }
    }

    if (!fileRef.save()) {
        result.status = TLTagWriteStatusSaveFailed;
        result.details = @"TagLib save() returned false";
        return result;
    }

    result.status = TLTagWriteStatusOk;
    return result;
}
