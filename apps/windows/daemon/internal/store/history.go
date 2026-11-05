package store

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"
)

type HistoryItem struct {
	SeriesID   string    `json:"seriesId"`
	EpisodeID  string    `json:"episodeId"`
	PositionMs int64     `json:"positionMs"`
	UpdatedAt  time.Time `json:"updatedAt"`
}

type History struct {
	mu    sync.Mutex
	path  string
	items []HistoryItem
}

func NewHistory(dir string) *History {
	h := &History{path: filepath.Join(dir, "history.json")}
	_ = h.load()
	return h
}

func (h *History) List() []HistoryItem {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := make([]HistoryItem, len(h.items))
	copy(out, h.items)
	return out
}

func (h *History) Upsert(item HistoryItem) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	item.UpdatedAt = time.Now().UTC()
	for i, it := range h.items {
		if it.SeriesID == item.SeriesID {
			h.items[i] = item
			return h.saveLocked()
		}
	}
	h.items = append(h.items, item)
	return h.saveLocked()
}

func (h *History) Delete(seriesID string) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	next := h.items[:0]
	for _, it := range h.items {
		if it.SeriesID != seriesID {
			next = append(next, it)
		}
	}
	h.items = next
	return h.saveLocked()
}

func (h *History) load() error {
	b, err := os.ReadFile(h.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return json.Unmarshal(b, &h.items)
}

func (h *History) saveLocked() error {
	if err := os.MkdirAll(filepath.Dir(h.path), 0o700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(h.items, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(h.path, b, 0o600)
}
