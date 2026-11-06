package ohg

import (
	"context"
	"errors"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"github.com/beilunyang/openhongguo/adapters"
	"github.com/beilunyang/openhongguo/sdk"
	"github.com/beilunyang/openhongguo/sdk/model"
)

const (
	maxAttempts      = 4
	discoverAttempts = 2 // fast path: prefer fallback over long empty-tab retries
	discoverDeadline = 22 * time.Second
	searchDeadline   = 22 * time.Second
	discoverCache    = 10 * time.Minute
)

// Client wraps openhongguo SDK v0.2.0 for the local HTTP API.
type Client struct {
	inner *sdk.Client

	discoverMu sync.Mutex
	cachedDisc *sdk.Page[model.SeriesSummary]
	cachedAt   time.Time
	cachedSrc  string // "discover" | "search-fallback" | "newreleases-fallback"
}

// New creates an anonymous openhongguo client. deviceFile stores the device profile.
func New(deviceFile string) (*Client, error) {
	c, err := adapters.NewClient(deviceFile, sdk.Options{})
	if err != nil {
		return nil, fmt.Errorf("adapters.NewClient: %w", err)
	}
	return &Client{inner: c}, nil
}

func (c *Client) Close() {}

func isTransient(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return false
	}
	if sdk.Retryable(err) {
		return true
	}
	// Discover 空页：短时再试有时能出内容（注册刚完成 / 上游抖动）。
	if errors.Is(err, sdk.ErrAnonymousLimited) {
		return true
	}
	msg := strings.ToLower(err.Error())
	for _, needle := range []string{
		"502", "503", "504", "bad gateway", "gateway timeout",
		"timeout", "temporarily", "connection reset", "connection refused",
		"eof", "i/o timeout", "tls handshake", "broken pipe", "429",
		"anonymous response was empty",
	} {
		if strings.Contains(msg, needle) {
			return true
		}
	}
	return false
}

func sleepBackoff(ctx context.Context, attempt int) error {
	wait := time.Duration(attempt*attempt) * 400 * time.Millisecond
	if wait > 3*time.Second {
		wait = 3 * time.Second
	}
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(wait):
		return nil
	}
}

func (c *Client) Search(ctx context.Context, q string) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	start := time.Now()
	ctx, cancel := context.WithTimeout(ctx, searchDeadline)
	defer cancel()
	var last error
	// Cap retries so Search cannot burn the whole UI budget.
	const searchAttempts = 2
	for attempt := 1; attempt <= searchAttempts; attempt++ {
		page, err := c.inner.Search(ctx, q, sdk.SearchOptions{})
		if err == nil {
			c.enrichSearchCovers(ctx, page)
			log.Printf("ohg search ok q=%q items=%d elapsed=%s", q, len(page.Items), time.Since(start).Round(time.Millisecond))
			return page, nil
		}
		last = err
		if attempt == searchAttempts || !isTransient(err) {
			log.Printf("ohg search fail q=%q attempt=%d elapsed=%s err=%v", q, attempt, time.Since(start).Round(time.Millisecond), err)
			return nil, fmt.Errorf("search: %w", err)
		}
		if err := sleepBackoff(ctx, attempt); err != nil {
			return nil, err
		}
	}
	return nil, fmt.Errorf("search: %w", last)
}

// enrichSearchCovers fills CoverURL via GetSeriesBatch.
// openhongguo ParseSearch drops series_cover on the common series_title path,
// so /api/v1/search often returned titles with empty cover_url.
func (c *Client) enrichSearchCovers(ctx context.Context, page *sdk.Page[model.SeriesSummary]) {
	if c.inner == nil || page == nil || len(page.Items) == 0 {
		return
	}
	need := make([]string, 0, len(page.Items))
	for _, it := range page.Items {
		if it.CoverURL == "" && it.ID != "" {
			need = append(need, it.ID)
		}
	}
	if len(need) == 0 {
		return
	}
	// Cap to keep search snappy on soft networks.
	if len(need) > 12 {
		need = need[:12]
	}
	details, err := c.inner.GetSeriesBatch(ctx, need)
	if err != nil {
		log.Printf("ohg: search cover enrich: %v", err)
		return
	}
	byID := make(map[string]model.SeriesSummary, len(details))
	for _, d := range details {
		s := d.Series
		if s == nil || s.ID == "" || s.CoverURL == "" {
			continue
		}
		byID[s.ID] = s.SeriesSummary
	}
	for i := range page.Items {
		if page.Items[i].CoverURL != "" {
			continue
		}
		if s, ok := byID[page.Items[i].ID]; ok {
			page.Items[i].CoverURL = s.CoverURL
			page.Items[i].CoverExpiresAt = s.CoverExpiresAt
			if page.Items[i].EpisodeCount == 0 && s.EpisodeCount > 0 {
				page.Items[i].EpisodeCount = s.EpisodeCount
			}
			if page.Items[i].Description == "" && s.Description != "" {
				page.Items[i].Description = s.Description
			}
		}
	}
}

// Discover loads the bookstore recommend feed.
//
// Root cause of the user-facing "502": when the recommend tab returns 0 items,
// openhongguo yields ErrAnonymousLimited. Our HTTP API used to map *every*
// ohg error to status 502, so the UI showed Bad Gateway even though the local
// daemon was healthy and Search still worked. Here we recover by:
//  1. a hard overall deadline (~22s) so the UI never hangs for minutes;
//  2. a short discoverOnce (1–2 attempts) then ResetDevice once + rediscover;
//  3. falling back quickly to Search("短剧") / NewReleases;
//  4. serving a short-lived in-memory cache of the last good page.
func (c *Client) Discover(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}

	start := time.Now()
	ctx, cancel := context.WithTimeout(ctx, discoverDeadline)
	defer cancel()

	c.discoverMu.Lock()
	defer c.discoverMu.Unlock()

	page, err := c.discoverOnce(ctx)
	if err == nil && page != nil && len(page.Items) > 0 {
		c.rememberDiscover(page, "discover")
		log.Printf("ohg discover ok src=discover items=%d elapsed=%s", len(page.Items), time.Since(start).Round(time.Millisecond))
		return page, nil
	}

	if errors.Is(err, sdk.ErrAnonymousLimited) || (page != nil && len(page.Items) == 0) || isTransient(err) {
		log.Printf("ohg discover empty/limited/slow (%v) after %s; resetting anonymous device", err, time.Since(start).Round(time.Millisecond))
		if resetErr := c.inner.ResetDevice(ctx); resetErr != nil {
			log.Printf("ohg ResetDevice: %v", resetErr)
		} else if waitErr := sleepBackoff(ctx, 1); waitErr != nil {
			err = waitErr
		} else if page2, err2 := c.discoverOnce(ctx); err2 == nil && page2 != nil && len(page2.Items) > 0 {
			c.rememberDiscover(page2, "discover-after-reset")
			log.Printf("ohg discover ok src=discover-after-reset items=%d elapsed=%s", len(page2.Items), time.Since(start).Round(time.Millisecond))
			return page2, nil
		} else if err2 != nil {
			err = err2
		}
	}

	if fb, src, fbErr := c.discoverFallback(ctx); fbErr == nil && fb != nil && len(fb.Items) > 0 {
		log.Printf("ohg discover fallback via %s (%d items) elapsed=%s", src, len(fb.Items), time.Since(start).Round(time.Millisecond))
		c.rememberDiscover(fb, src)
		return fb, nil
	}

	if cached := c.cachedDiscover(); cached != nil {
		log.Printf("ohg discover serving stale cache (%d items, src=%s) elapsed=%s", len(cached.Items), c.cachedSrc, time.Since(start).Round(time.Millisecond))
		return cached, nil
	}

	if err == nil {
		err = sdk.ErrAnonymousLimited
	}
	if errors.Is(err, context.DeadlineExceeded) || errors.Is(ctx.Err(), context.DeadlineExceeded) {
		err = fmt.Errorf("discover deadline exceeded after %s: %w", time.Since(start).Round(time.Millisecond), err)
	}
	log.Printf("ohg discover fail elapsed=%s err=%v", time.Since(start).Round(time.Millisecond), err)
	return nil, fmt.Errorf("discover: %w", err)
}

func (c *Client) discoverOnce(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	var last error
	for attempt := 1; attempt <= discoverAttempts; attempt++ {
		page, err := c.inner.Discover(ctx, sdk.DiscoverOptions{})
		if err == nil && page != nil && len(page.Items) > 0 {
			return page, nil
		}
		if err == nil {
			err = sdk.ErrAnonymousLimited
		}
		last = err
		if attempt == discoverAttempts || !isTransient(err) {
			return nil, err
		}
		if waitErr := sleepBackoff(ctx, attempt); waitErr != nil {
			return nil, waitErr
		}
	}
	return nil, last
}

func (c *Client) discoverFallback(ctx context.Context) (*sdk.Page[model.SeriesSummary], string, error) {
	// Search is the path that kept working while Discover returned empty in repro.
	if page, err := c.inner.Search(ctx, "短剧", sdk.SearchOptions{}); err == nil && page != nil && len(page.Items) > 0 {
		return page, "search-fallback", nil
	}
	if nr, err := c.inner.NewReleases(ctx, sdk.NewReleaseQuery{}); err == nil && nr != nil && len(nr.Items) > 0 {
		items := make([]model.SeriesSummary, 0, len(nr.Items))
		for _, it := range nr.Items {
			items = append(items, model.SeriesSummary{
				ID:           it.SeriesID,
				Title:        it.Title,
				Description:  it.Description,
				CoverURL:     it.CoverURL,
				EpisodeCount: it.EpisodeCount,
			})
		}
		return &sdk.Page[model.SeriesSummary]{Items: items, HasMore: nr.HasMore}, "newreleases-fallback", nil
	}
	return nil, "", fmt.Errorf("no fallback catalog")
}

func (c *Client) rememberDiscover(page *sdk.Page[model.SeriesSummary], src string) {
	// Shallow copy items slice header so later mutations don't surprise callers.
	cp := &sdk.Page[model.SeriesSummary]{
		Items:   append([]model.SeriesSummary(nil), page.Items...),
		HasMore: page.HasMore,
	}
	c.cachedDisc = cp
	c.cachedAt = time.Now()
	c.cachedSrc = src
}

func (c *Client) cachedDiscover() *sdk.Page[model.SeriesSummary] {
	if c.cachedDisc == nil || time.Since(c.cachedAt) > discoverCache {
		return nil
	}
	cp := &sdk.Page[model.SeriesSummary]{
		Items:   append([]model.SeriesSummary(nil), c.cachedDisc.Items...),
		HasMore: c.cachedDisc.HasMore,
	}
	return cp
}

func (c *Client) ListEpisodes(ctx context.Context, seriesID string) (*sdk.Page[model.Episode], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	var last error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		page, err := c.inner.ListEpisodes(ctx, seriesID, sdk.EpisodeOptions{})
		if err == nil {
			return page, nil
		}
		last = err
		if attempt == maxAttempts || !isTransient(err) {
			return nil, fmt.Errorf("episodes: %w", err)
		}
		if err := sleepBackoff(ctx, attempt); err != nil {
			return nil, err
		}
	}
	return nil, fmt.Errorf("episodes: %w", last)
}

// ResolvePlayback returns the playback model. Protected streams may still return
// a non-nil model together with sdk.ErrDRMProtected; callers should use sdk.ContentKey.
func (c *Client) ResolvePlayback(ctx context.Context, episodeID string) (*model.Playback, error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	var last error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		pb, err := c.inner.ResolvePlayback(ctx, episodeID, sdk.PlaybackOptions{})
		if pb != nil && (err == nil || errors.Is(err, sdk.ErrDRMProtected)) {
			return pb, err
		}
		last = err
		if err == nil {
			last = fmt.Errorf("empty playback")
		}
		if attempt == maxAttempts || !isTransient(last) {
			if pb != nil {
				return pb, last
			}
			return nil, fmt.Errorf("playback: %w", last)
		}
		if err := sleepBackoff(ctx, attempt); err != nil {
			return nil, err
		}
	}
	return nil, fmt.Errorf("playback: %w", last)
}

// GetSeriesBatch loads titles/covers for favorites and history enrichment.
func (c *Client) GetSeriesBatch(ctx context.Context, ids []string) ([]model.SeriesSummary, error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	cleaned := make([]string, 0, len(ids))
	seen := map[string]bool{}
	for _, id := range ids {
		id = strings.TrimSpace(id)
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		cleaned = append(cleaned, id)
	}
	if len(cleaned) == 0 {
		return nil, nil
	}
	if len(cleaned) > 20 {
		cleaned = cleaned[:20]
	}
	details, err := c.inner.GetSeriesBatch(ctx, cleaned)
	if err != nil {
		return nil, fmt.Errorf("series batch: %w", err)
	}
	out := make([]model.SeriesSummary, 0, len(details))
	for _, d := range details {
		if d.Series == nil || d.Series.ID == "" {
			continue
		}
		out = append(out, d.Series.SeriesSummary)
	}
	return out, nil
}
