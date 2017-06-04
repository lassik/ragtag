#include <taglib.h>
#include <fileref.h>

extern "C" {
#include "server.h"
}

static TagLib::FileRef *fr;
static TagLib::Tag *tag;
static bool writeOnClose;

extern unsigned int TagClose(void) {
	int succeeded = 1;
	if (writeOnClose) {
		if (!fr->save()) {
			succeeded = 0;
		}
	}
	writeOnClose = false;
	tag = NULL;
	delete fr;
	fr = NULL;
	return succeeded;
}

static unsigned int TagOpen(char *filename, bool wantWrite) {
	TagClose();
	fr = new TagLib::FileRef(filename);
	free(filename);
	tag = fr->isNull() ? NULL : fr->tag();
	writeOnClose = wantWrite;
	return tag != NULL;
}

extern unsigned int TagOpenRead(char *filename) {
	return TagOpen(filename, false);
}

extern unsigned int TagOpenWrite(char *filename) {
	return TagOpen(filename, true);
}


extern const char *TagReadArtist(void) {
	return tag ? tag->artist().toCString(true) : "";
}

extern unsigned int TagReadYear(void) {
	return tag ? tag->year() : 0;
}

extern const char *TagReadAlbum(void) {
	return tag ? tag->album().toCString(true) : "";
}

extern unsigned int TagReadTrackNumber(void) {
	return tag ? tag->track() : 0;
}

extern const char *TagReadTrackTitle(void) {
	return tag ? tag->title().toCString(true) : "";
}

extern const char *TagReadGenre(void) {
	return tag ? tag->genre().toCString(true) : "";
}

extern void TagWriteArtist(const char *newValue) {
	TagLib::String stringValue(newValue);
	tag->setArtist(stringValue);
}

extern void TagWriteYear(unsigned int newValue) {
	tag->setYear(newValue);
}

extern void TagWriteAlbum(const char *newValue) {
	TagLib::String stringValue(newValue);
	tag->setAlbum(stringValue);
}

extern void TagWriteTrackNumber(unsigned int newValue) {
	tag->setTrack(newValue);
}

extern void TagWriteTrackTitle(const char *newValue) {
	TagLib::String stringValue(newValue);
	tag->setTitle(stringValue);
}

extern void TagWriteGenre(const char *newValue) {
	TagLib::String stringValue(newValue);
	tag->setGenre(stringValue);
}
