//
//  TLTagLibFile.mm
//  TrackList
//
//  Реализация чтения метаданных через TagLib C++.
//  Используется в Swift через Bridging Header.
//
//  Created by Pavel Fomin on 21.06.2025.
//

#import <Foundation/Foundation.h>
#import "TLTagLibFile.h"

#include <fileref.h>
#include <tag.h>
#include <tstring.h>
#include <tstringlist.h>
#include <tpropertymap.h>
#include <string>

#include <mpeg/mpegfile.h>
#include <mpeg/id3v2/id3v2tag.h>
#include <mpeg/id3v2/frames/attachedpictureframe.h>

#include <flac/flacfile.h>
#include <flac/flacpicture.h>

#include <ogg/xiphcomment.h>
#include <ogg/vorbis/vorbisfile.h>
#include <ogg/opus/opusfile.h>

static inline NSString *TLNSStringFromTagLibString(const TagLib::String &value) {
    if (value.isEmpty()) {return nil;}

    std::string utf8 = value.to8Bit(true);
    if (utf8.empty()) {return nil;}

    return [[NSString alloc] initWithBytes:utf8.data()
                                    length:(NSUInteger)utf8.size()
                                  encoding:NSUTF8StringEncoding];
}

static inline NSData *TLNSDataFromByteVector(const TagLib::ByteVector &value) {
    if (value.isEmpty()) {return nil;}
    return [NSData dataWithBytes:value.data() length:(NSUInteger)value.size()];
}

static inline NSString *TLReadFirstPropertyValue(
    const TagLib::PropertyMap &properties,
    const char *key
) {
    auto it = properties.find(key);
    if (it == properties.end()) {return nil;}
    if (it->second.isEmpty()) {return nil;}
    return TLNSStringFromTagLibString(it->second.front());
}

static NSData *TLReadArtworkFromMP3(TagLib::MPEG::File *file) {
    if (!file) {return nil;}

    TagLib::ID3v2::Tag *tag = file->ID3v2Tag(false);
    if (!tag) {return nil;}

    const TagLib::ID3v2::FrameList frames = tag->frameListMap()["APIC"];
    if (frames.isEmpty()) {return nil;}

    auto *pictureFrame = dynamic_cast<TagLib::ID3v2::AttachedPictureFrame *>(frames.front());
    if (!pictureFrame) {return nil;}

    return TLNSDataFromByteVector(pictureFrame->picture());
}

static NSData *TLReadArtworkFromFLAC(TagLib::FLAC::File *file) {
    if (!file) {return nil;}

    const TagLib::List<TagLib::FLAC::Picture *> pictures = file->pictureList();
    if (pictures.isEmpty()) {return nil;}
    if (!pictures.front()) {return nil;}

    return TLNSDataFromByteVector(pictures.front()->data());
}

static NSData *TLReadArtworkFromXiph(TagLib::Ogg::XiphComment *tag) {
    if (!tag) {return nil;}

    const TagLib::List<TagLib::FLAC::Picture *> pictures = tag->pictureList();
    if (pictures.isEmpty()) {return nil;}
    if (!pictures.front()) {return nil;}

    return TLNSDataFromByteVector(pictures.front()->data());
}

static NSData *TLReadArtwork(TagLib::FileRef &fileRef) {
    TagLib::File *baseFile = fileRef.file();
    if (!baseFile) {return nil;}

    auto *mp3File = dynamic_cast<TagLib::MPEG::File *>(baseFile);
    if (mp3File) {return TLReadArtworkFromMP3(mp3File);}

    auto *flacFile = dynamic_cast<TagLib::FLAC::File *>(baseFile);
    if (flacFile) {return TLReadArtworkFromFLAC(flacFile);}

    auto *vorbisFile = dynamic_cast<TagLib::Ogg::Vorbis::File *>(baseFile);
    if (vorbisFile) {return TLReadArtworkFromXiph(vorbisFile->tag());}

    auto *opusFile = dynamic_cast<TagLib::Ogg::Opus::File *>(baseFile);
    if (opusFile) {return TLReadArtworkFromXiph(opusFile->tag());}

    return nil;
}

@implementation TLTagLibFileResult
@end

TLTagLibFileResult *_Nullable _readMetadata(NSString *filePath) {
    const char *cPath = [filePath fileSystemRepresentation];
    if (!cPath) {return nil;}

    TagLib::FileRef fileRef(cPath);
    if (fileRef.isNull()) {return nil;}

    TagLib::Tag *tag = fileRef.tag();
    if (!tag) {return nil;}

    TLTagLibFileResult *result = [TLTagLibFileResult new];

    result.title = TLNSStringFromTagLibString(tag->title());
    result.artist = TLNSStringFromTagLibString(tag->artist());
    result.album = TLNSStringFromTagLibString(tag->album());
    result.genre = TLNSStringFromTagLibString(tag->genre());
    result.comment = TLNSStringFromTagLibString(tag->comment());

    if (tag->year() > 0) {
        result.year = @(tag->year());
    }

    TagLib::File *baseFile = fileRef.file();
    if (baseFile) {
        TagLib::PropertyMap properties = baseFile->properties();

        NSString *publisher = TLReadFirstPropertyValue(properties, "PUBLISHER");
        if (!publisher) {publisher = TLReadFirstPropertyValue(properties, "LABEL");}
        if (!publisher) {publisher = TLReadFirstPropertyValue(properties, "ORGANIZATION");}

        result.publisher = publisher;
    }

    result.artworkData = TLReadArtwork(fileRef);

    return result;
}
