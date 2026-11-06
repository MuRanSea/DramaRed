package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/beilunyang/openhongguo/sdk"

	"github.com/MuRanSea/DramaRed/apps/desktop/daemon/internal/ohg"
	"github.com/MuRanSea/DramaRed/apps/desktop/daemon/internal/store"
)

type Server struct {
	ohg  *ohg.Client
	hist *store.History
	favs *store.Favorites
	mux  *http.ServeMux
}

func NewServer(c *ohg.Client, hist *store.History, favs *store.Favorites) *Server {
	s := &Server{ohg: c, hist: hist, favs: favs, mux: http.NewServeMux()}
	s.routes()
	return s
}

func (s *Server) Handler() http.Handler { return s.mux }

func (s *Server) routes() {
	s.mux.HandleFunc("GET /health", s.health)
	s.mux.HandleFunc("GET /api/v1/search", s.search)
	s.mux.HandleFunc("GET /api/v1/discover", s.discover)
	s.mux.HandleFunc("GET /api/v1/series/{id}/episodes", s.episodes)
	s.mux.HandleFunc("GET /api/v1/episodes/{id}/playback", s.playback)
	s.mux.HandleFunc("GET /api/v1/history", s.historyList)
	s.mux.HandleFunc("POST /api/v1/history", s.historyUpsert)
	s.mux.HandleFunc("DELETE /api/v1/history", s.historyDelete)
	s.mux.HandleFunc("GET /api/v1/favorites", s.favoritesList)
	s.mux.HandleFunc("POST /api/v1/favorites", s.favoritesAdd)
	s.mux.HandleFunc("DELETE /api/v1/favorites", s.favoritesRemove)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{
		"error":   msg,
		"message": friendlyUpstream(msg),
	})
}

func friendlyUpstream(raw string) string {
	low := strings.ToLower(raw)
	switch {
	case strings.Contains(low, "502"), strings.Contains(low, "bad gateway"):
		return "上游短剧服务暂时不可用（网关错误），请稍后重试"
	case strings.Contains(low, "503"), strings.Contains(low, "unavailable"):
		return "上游短剧服务繁忙，请稍后重试"
	case strings.Contains(low, "504"), strings.Contains(low, "timeout"):
		return "上游短剧服务响应超时，请稍后重试"
	case strings.Contains(low, "429"):
		return "请求过于频繁，请稍后再试"
	case strings.Contains(low, "connection refused"), strings.Contains(low, "network"):
		return "网络连接失败，请检查网络后重试"
	default:
		return "获取内容失败，请稍后重试"
	}
}

func (s *Server) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"service": "drama-daemon",
		"sdk":     "openhongguo@v0.2.0",
	})
}

func (s *Server) search(w http.ResponseWriter, r *http.Request) {
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		writeErr(w, http.StatusBadRequest, "missing q")
		return
	}
	page, err := s.ohg.Search(r.Context(), q)
	if err != nil {
		writeErr(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) discover(w http.ResponseWriter, r *http.Request) {
	page, err := s.ohg.Discover(r.Context())
	if err != nil {
		writeErr(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) episodes(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	page, err := s.ohg.ListEpisodes(r.Context(), id)
	if err != nil {
		writeErr(w, http.StatusBadGateway, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, page)
}

func (s *Server) playback(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	pb, err := s.ohg.ResolvePlayback(r.Context(), id)
	if pb == nil {
		if err != nil {
			writeErr(w, http.StatusBadGateway, err.Error())
			return
		}
		writeErr(w, http.StatusBadGateway, "empty playback")
		return
	}
	out := map[string]any{"playback": pb}
	if err != nil {
		out["warning"] = err.Error()
		if errors.Is(err, sdk.ErrDRMProtected) {
			out["drmProtected"] = true
			if key, keyErr := sdk.ContentKey(pb); keyErr == nil {
				out["contentKey"] = key
			} else {
				out["contentKeyError"] = keyErr.Error()
			}
		}
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) historyList(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"items": s.hist.List()})
}

func (s *Server) historyUpsert(w http.ResponseWriter, r *http.Request) {
	var item store.HistoryItem
	if err := json.NewDecoder(r.Body).Decode(&item); err != nil {
		writeErr(w, http.StatusBadRequest, err.Error())
		return
	}
	if item.SeriesID == "" || item.EpisodeID == "" {
		writeErr(w, http.StatusBadRequest, "seriesId and episodeId required")
		return
	}
	if err := s.hist.Upsert(item); err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) historyDelete(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("seriesId")
	if id == "" {
		writeErr(w, http.StatusBadRequest, "missing seriesId")
		return
	}
	if err := s.hist.Delete(id); err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) favoritesList(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{"seriesIds": s.favs.List()})
}

func (s *Server) favoritesAdd(w http.ResponseWriter, r *http.Request) {
	var body struct {
		SeriesID string `json:"seriesId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.SeriesID == "" {
		writeErr(w, http.StatusBadRequest, "seriesId required")
		return
	}
	if err := s.favs.Add(body.SeriesID); err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) favoritesRemove(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("seriesId")
	if id == "" {
		writeErr(w, http.StatusBadRequest, "missing seriesId")
		return
	}
	if err := s.favs.Remove(id); err != nil {
		writeErr(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
