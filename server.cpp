#include <taglib.h>
#include <fileref.h>

extern "C" {
#include "server.h"
}

static TagLib::FileRef *fr;
static TagLib::Tag *tag;

extern void TagClose(void) {
	tag = NULL;
	delete fr;
	fr = NULL;
}

extern unsigned int TagOpenRead(char *filename) {
	TagClose();
	fr = new TagLib::FileRef(filename);
	free(filename);
	tag = fr->isNull() ? NULL : fr->tag();
	return tag != NULL;
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
