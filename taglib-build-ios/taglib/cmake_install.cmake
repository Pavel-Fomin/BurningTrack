# Install script for directory: /Users/pavelfomin/Documents/taglib/taglib

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/install")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/usr/bin/objdump")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/libtag.a")
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libtag.a" AND
     NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libtag.a")
    execute_process(COMMAND "/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libtag.a")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/taglib" TYPE FILE FILES
    "/Users/pavelfomin/Documents/taglib/taglib/tag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/fileref.h"
    "/Users/pavelfomin/Documents/taglib/taglib/audioproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/taglib_export.h"
    "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/../taglib_config.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/taglib.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tstring.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tlist.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tlist.tcc"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tstringlist.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tbytevector.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tbytevectorlist.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tvariant.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tbytevectorstream.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tiostream.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tfilestream.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tmap.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tmap.tcc"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tpicturetype.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tpropertymap.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tdebuglistener.h"
    "/Users/pavelfomin/Documents/taglib/taglib/toolkit/tversionnumber.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/mpegfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/mpegproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/mpegheader.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/xingheader.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v1/id3v1tag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v1/id3v1genres.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2extendedheader.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2frame.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2header.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2synchdata.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2footer.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2framefactory.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/id3v2tag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/attachedpictureframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/commentsframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/eventtimingcodesframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/generalencapsulatedobjectframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/ownershipframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/popularimeterframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/privateframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/relativevolumeframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/synchronizedlyricsframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/textidentificationframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/uniquefileidentifierframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/unknownframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/unsynchronizedlyricsframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/urllinkframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/chapterframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/tableofcontentsframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpeg/id3v2/frames/podcastframe.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/oggfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/oggpage.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/oggpageheader.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/xiphcomment.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/vorbis/vorbisfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/vorbis/vorbisproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/flac/oggflacfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/speex/speexfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/speex/speexproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/opus/opusfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ogg/opus/opusproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/flac/flacfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/flac/flacpicture.h"
    "/Users/pavelfomin/Documents/taglib/taglib/flac/flacproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/flac/flacmetadatablock.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ape/apefile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ape/apeproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ape/apetag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ape/apefooter.h"
    "/Users/pavelfomin/Documents/taglib/taglib/ape/apeitem.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpc/mpcfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mpc/mpcproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/wavpack/wavpackfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/wavpack/wavpackproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/trueaudio/trueaudiofile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/trueaudio/trueaudioproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/rifffile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/aiff/aifffile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/aiff/aiffproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/wav/wavfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/wav/wavproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/riff/wav/infotag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/asf/asffile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/asf/asfproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/asf/asftag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/asf/asfattribute.h"
    "/Users/pavelfomin/Documents/taglib/taglib/asf/asfpicture.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4file.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4atom.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4tag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4item.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4properties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4coverart.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mp4/mp4itemfactory.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mod/modfilebase.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mod/modfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mod/modtag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/mod/modproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/it/itfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/it/itproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/s3m/s3mfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/s3m/s3mproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/xm/xmfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/xm/xmproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/dsf/dsffile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/dsf/dsfproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/dsdiff/dsdifffile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/dsdiff/dsdiffproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/dsdiff/dsdiffdiintag.h"
    "/Users/pavelfomin/Documents/taglib/taglib/shorten/shortenfile.h"
    "/Users/pavelfomin/Documents/taglib/taglib/shorten/shortenproperties.h"
    "/Users/pavelfomin/Documents/taglib/taglib/shorten/shortentag.h"
    )
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib/taglib-targets.cmake")
    file(DIFFERENT _cmake_export_file_changed FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib/taglib-targets.cmake"
         "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/CMakeFiles/Export/398eef5e047a0959864f2888198961bf/taglib-targets.cmake")
    if(_cmake_export_file_changed)
      file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib/taglib-targets-*.cmake")
      if(_cmake_old_config_files)
        string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib/taglib-targets.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
        unset(_cmake_old_config_files_text)
        file(REMOVE ${_cmake_old_config_files})
      endif()
      unset(_cmake_old_config_files)
    endif()
    unset(_cmake_export_file_changed)
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib" TYPE FILE FILES "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/CMakeFiles/Export/398eef5e047a0959864f2888198961bf/taglib-targets.cmake")
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^()$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib" TYPE FILE FILES "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/CMakeFiles/Export/398eef5e047a0959864f2888198961bf/taglib-targets-noconfig.cmake")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/taglib" TYPE FILE FILES
    "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib-config.cmake"
    "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib-config-version.cmake"
    )
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
  file(WRITE "/Users/pavelfomin/Documents/TrackList/taglib-build-ios/taglib/install_local_manifest.txt"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
