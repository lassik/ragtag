package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
)

// #cgo pkg-config: taglib
// #include "server.h"
import "C"

var rootDirectory string

type Track struct {
	TrackId     string
	Filename    string
	Artist      string
	Year        string
	Album       string
	TrackNumber string
	TrackTitle  string
	Genre       string
}

type TracksResponse struct {
	Tracks []Track
}

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

func trackFromFilePath(filePath string) *Track {
	gotTag := C.TagOpenRead(C.CString(filePath)) != 0
	defer C.TagClose()
	if !gotTag {
		return nil
	}
	return &Track{
		TrackId:     trackIdFromFilePath(filePath),
		Filename:    filePath,
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

func isRegularFile(mode os.FileMode) bool {
	return mode&os.ModeType == 0
}

func tracksFromRootDirectory() TracksResponse {
	var resp TracksResponse
	filepath.Walk(rootDirectory,
		func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return nil
			}
			if !isRegularFile(info.Mode()) {
				return nil
			}
			track := trackFromFilePath(path)
			if track == nil {
				return nil
			}
			resp.Tracks = append(resp.Tracks, *track)
			return nil
		})
	return resp
}

func writeTrackTag(w http.ResponseWriter, r *http.Request) {
	var track Track
	body, err := ioutil.ReadAll(io.LimitReader(r.Body, 1048576))
	if err != nil {
		panic(err)
	}
	if err := r.Body.Close(); err != nil {
		panic(err)
	}
	if err := json.Unmarshal(body, &track); err != nil {
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		w.WriteHeader(422) // unprocessable entity
		if err := json.NewEncoder(w).Encode(err); err != nil {
			panic(err)
		}
	}

	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(track); err != nil {
		panic(err)
	}
}

func handler(w http.ResponseWriter, r *http.Request) {
	p := r.URL.Path
	if p == "/" {
		http.ServeFile(w, r, "index.html")
	} else if p == "/elm.js" {
		http.ServeFile(w, r, "elm.js")
	} else if p == "/style.css" {
		fmt.Fprint(w, "")
	} else if p == "/tracks" {
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
