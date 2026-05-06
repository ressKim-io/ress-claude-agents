package main

// fixture: extra .go file so Go beats single-file extensions
// (Dockerfile, README.md, ci.yml) for primary language detection.

func health() string {
	return "ok"
}
