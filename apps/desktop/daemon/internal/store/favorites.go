package store

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

type Favorites struct {
	mu   sync.Mutex
	path string
	ids  []string
}

func NewFavorites(dir string) *Favorites {
	f := &Favorites{path: filepath.Join(dir, "favorites.json")}
	_ = f.load()
	return f
}

func (f *Favorites) List() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]string, len(f.ids))
	copy(out, f.ids)
	return out
}

func (f *Favorites) Add(seriesID string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	for _, id := range f.ids {
		if id == seriesID {
			return nil
		}
	}
	f.ids = append(f.ids, seriesID)
	return f.saveLocked()
}

func (f *Favorites) Remove(seriesID string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	next := f.ids[:0]
	for _, id := range f.ids {
		if id != seriesID {
			next = append(next, id)
		}
	}
	f.ids = next
	return f.saveLocked()
}

func (f *Favorites) load() error {
	b, err := os.ReadFile(f.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return json.Unmarshal(b, &f.ids)
}

func (f *Favorites) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(f.path), 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(f.ids, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(f.path, b, 0o600)
}
