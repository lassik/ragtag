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

func stringFromPosInt(val int) string {
	if val < 1 {
		return ""
	} else {
		return fmt.Sprintf("%d", val)
	}
}

func trackFromFilePath(filePath string) Track {
	C.TagOpenRead(C.CString(filePath))
	defer C.TagClose()
	return Track{
		TrackId:     trackIdFromFilePath(filePath),
		Artist:      C.GoString(C.TagReadArtist()),
		Year:        stringFromPosInt(int(C.TagReadYear())),
		Album:       C.GoString(C.TagReadAlbum()),
		TrackNumber: stringFromPosInt(int(C.TagReadTrackNumber())),
		TrackTitle:  C.GoString(C.TagReadTrackTitle()),
		Genre:       C.GoString(C.TagReadGenre()),
	}
}

func serveJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		http.Error(w, err.Error(), 500)
	}
}

func tracksFromRootDirectory() Tracks {
	var tracks Tracks
	filePaths, _ := filepath.Glob(path.Join(rootDirectory, "*"))
	for _, filePath := range filePaths {
		tracks = append(tracks, trackFromFilePath(filePath))
	}
	return tracks
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
		serveJSON(w, tracksFromRootDirectory())
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
