//
//  TagCTest.m
//  TrackList
//
//  Created by Pavel Fomin on 20.06.2025.
//

#import <Foundation/Foundation.h>
#import <tag_c/tag_c.h>

void testTagC(const char *path) {
    taglib_set_strings_unicode(1);
    TagLib_File *file = taglib_file_new(path);

    if (file) {
        const TagLib_Tag *tag = taglib_file_tag(file);
        if (tag) {
            const char *title = taglib_tag_title(tag);
            printf("📀 Title: %s\n", title);
        }
        taglib_file_free(file);
    } else {
        printf("❌ Не удалось открыть файл: %s\n", path);
    }
}
