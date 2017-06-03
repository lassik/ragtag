package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"path"
	"path/filepath"
)

// #cgo pkg-config: taglib
// #include "server.h"
import "C"

var rootDirectory string

type Track struct {
	TrackId     string
	Artist      string
	Year        string
	Album       string
	TrackNumber string
	TrackTitle  string
	Genre       string
}

type Tracks []Track

func trackIdFromFilePath(filePath string) string {
	return base64.RawURLEncoding.EncodeToString([]byte(filePath))
}

func filePathFromTrackId(trackId string) string {
	filePath, _ := base64.RawURLEncoding.DecodeString(trackId)
	return string(filePath)
}

func numberToString(number C.int) string {
	if number < 1 {
		return ""
	} else {
		return fmt.Sprintf("%d", number)
	}
}

func trackFromFilePath(filePath string) Track {
	C.TagOpenRead(C.CString(filePath))
	defer C.TagClose()
	return Track{
		TrackId:     trackIdFromFilePath(filePath),
		Artist:      C.GoString(C.TagReadArtist()),
		Year:        numberToString(C.TagReadYear()),
		Album:       C.GoString(C.TagReadAlbum()),
		TrackNumber: numberToString(C.TagReadTrackNumber()),
		TrackTitle:  C.GoString(C.TagReadTrackTitle()),
		Genre:       C.GoString(C.TagReadGenre()),
	}
}

func directoryListHandler(w http.ResponseWriter, r *http.Request) {
	var tracks Tracks
	filePaths, _ := filepath.Glob(path.Join(rootDirectory, "*"))
	for _, filePath := range filePaths {
		tracks = append(tracks, trackFromFilePath(filePath))
	}
	json.NewEncoder(w).Encode(tracks)
}

func handler(w http.ResponseWriter, r *http.Request) {
	p := r.URL.Path
	if p == "/" {
		http.ServeFile(w, r, "index.html")
	} else if p == "/elm.js" {
		http.ServeFile(w, r, "elm.js")
	} else if p == "/style.css" {
		fmt.Fprint(w, "")
	} else if p == "/files" {
		directoryListHandler(w, r)
	} else {
		http.Error(w, "File not found.", 404)
	}
}

func main() {
	flag.Parse()
	rootDirectory = flag.Args()[0]
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8000", nil))
}
