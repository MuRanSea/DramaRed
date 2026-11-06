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
	maxAttempts   = 4
	discoverCache = 10 * time.Minute
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
	var last error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		page, err := c.inner.Search(ctx, q, sdk.SearchOptions{})
		if err == nil {
			c.enrichSearchCovers(ctx, page)
			return page, nil
		}
		last = err
		if attempt == maxAttempts || !isTransient(err) {
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
//  1. retrying transient failures (incl. empty anonymous tab);
//  2. ResetDevice once then rediscover;
//  3. falling back to Search("短剧") / NewReleases;
//  4. serving a short-lived in-memory cache of the last good page.
func (c *Client) Discover(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}

	c.discoverMu.Lock()
	defer c.discoverMu.Unlock()

	page, err := c.discoverOnce(ctx)
	if err == nil && page != nil && len(page.Items) > 0 {
		c.rememberDiscover(page, "discover")
		return page, nil
	}

	if errors.Is(err, sdk.ErrAnonymousLimited) || (page != nil && len(page.Items) == 0) {
		log.Printf("ohg discover empty/limited (%v); resetting anonymous device", err)
		if resetErr := c.inner.ResetDevice(ctx); resetErr != nil {
			log.Printf("ohg ResetDevice: %v", resetErr)
		} else if err := sleepBackoff(ctx, 1); err != nil {
			return nil, err
		} else if page2, err2 := c.discoverOnce(ctx); err2 == nil && page2 != nil && len(page2.Items) > 0 {
			c.rememberDiscover(page2, "discover-after-reset")
			return page2, nil
		} else if err2 != nil {
			err = err2
		}
	}

	if fb, src, fbErr := c.discoverFallback(ctx); fbErr == nil && fb != nil && len(fb.Items) > 0 {
		log.Printf("ohg discover fallback via %s (%d items)", src, len(fb.Items))
		c.rememberDiscover(fb, src)
		return fb, nil
	}

	if cached := c.cachedDiscover(); cached != nil {
		log.Printf("ohg discover serving stale cache (%d items, src=%s)", len(cached.Items), c.cachedSrc)
		return cached, nil
	}

	if err == nil {
		err = sdk.ErrAnonymousLimited
	}
	return nil, fmt.Errorf("discover: %w", err)
}

func (c *Client) discoverOnce(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	var last error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		page, err := c.inner.Discover(ctx, sdk.DiscoverOptions{})
		if err == nil && page != nil && len(page.Items) > 0 {
			return page, nil
		}
		if err == nil {
			err = sdk.ErrAnonymousLimited
		}
		last = err
		if attempt == maxAttempts || !isTransient(err) {
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
