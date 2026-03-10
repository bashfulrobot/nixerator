package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

var (
	directories []string
	envFile     string
)

type dirEntry struct {
	Index int    `json:"index"`
	Path  string `json:"path"`
	Name  string `json:"name"`
}

func isRunning() bool {
	out, _ := exec.Command("systemctl", "--user", "is-active", "termly").Output()
	return strings.TrimSpace(string(out)) == "active"
}

func currentDirectory() string {
	data, err := os.ReadFile(envFile)
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "TERMLY_DIR=") {
			return strings.TrimPrefix(line, "TERMLY_DIR=")
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	running := isRunning()
	dir := ""
	if running {
		dir = currentDirectory()
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"running":   running,
		"directory": dir,
	})
}

func handleDirectories(w http.ResponseWriter, r *http.Request) {
	entries := make([]dirEntry, len(directories))
	for i, d := range directories {
		entries[i] = dirEntry{Index: i, Path: d, Name: filepath.Base(d)}
	}
	writeJSON(w, http.StatusOK, map[string]any{"directories": entries})
}

func handleStart(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	if isRunning() {
		writeJSON(w, http.StatusConflict, map[string]any{
			"error":     "termly is already running",
			"directory": currentDirectory(),
		})
		return
	}

	dirParam := r.URL.Query().Get("dir")
	if dirParam == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "missing dir parameter"})
		return
	}

	var targetDir string
	if idx, err := strconv.Atoi(dirParam); err == nil && idx >= 0 && idx < len(directories) {
		targetDir = directories[idx]
	} else {
		for _, d := range directories {
			if filepath.Base(d) == dirParam {
				targetDir = d
				break
			}
		}
	}

	if targetDir == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid directory: " + dirParam})
		return
	}

	if err := os.WriteFile(envFile, []byte("TERMLY_DIR="+targetDir+"\n"), 0644); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	exec.Command("systemctl", "--user", "start", "termly").Run()
	writeJSON(w, http.StatusOK, map[string]any{"started": true, "directory": targetDir})
}

func handleStop(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
		return
	}

	if !isRunning() {
		writeJSON(w, http.StatusOK, map[string]any{"stopped": true, "was_running": false})
		return
	}

	exec.Command("systemctl", "--user", "stop", "termly").Run()
	writeJSON(w, http.StatusOK, map[string]any{"stopped": true, "was_running": true})
}

func main() {
	envFile = os.Getenv("TERMLY_ENV_FILE")
	if envFile == "" {
		envFile = "/tmp/termly-session.env"
	}

	dirsFile := os.Getenv("TERMLY_DIRECTORIES_FILE")
	if dirsFile != "" {
		data, err := os.ReadFile(dirsFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to read directories file: %v\n", err)
			os.Exit(1)
		}
		if err := json.Unmarshal(data, &directories); err != nil {
			fmt.Fprintf(os.Stderr, "failed to parse directories file: %v\n", err)
			os.Exit(1)
		}
	}

	port := "9735"
	if len(os.Args) > 1 {
		port = os.Args[1]
	}

	http.HandleFunc("/status", handleStatus)
	http.HandleFunc("/directories", handleDirectories)
	http.HandleFunc("/start", handleStart)
	http.HandleFunc("/stop", handleStop)

	fmt.Printf("Termly trigger listening on port %s\n", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		fmt.Fprintf(os.Stderr, "server error: %v\n", err)
		os.Exit(1)
	}
}
