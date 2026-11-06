package ohg

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/beilunyang/openhongguo/adapters"
	"github.com/beilunyang/openhongguo/sdk"
	"github.com/beilunyang/openhongguo/sdk/model"
)

const maxAttempts = 4

// Client wraps openhongguo SDK v0.2.0 for the local HTTP API.
type Client struct {
	inner *sdk.Client
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
	msg := strings.ToLower(err.Error())
	for _, needle := range []string{
		"502", "503", "504", "bad gateway", "gateway timeout",
		"timeout", "temporarily", "connection reset", "connection refused",
		"eof", "i/o timeout", "tls handshake", "broken pipe", "429",
	} {
		if strings.Contains(msg, needle) {
			return true
		}
	}
	return false
}

func sleepBackoff(ctx context.Context, attempt int) error {
	delay := time.Duration(attempt*attempt) * 300 * time.Millisecond
	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(delay):
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

func (c *Client) Discover(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	var last error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		page, err := c.inner.Discover(ctx, sdk.DiscoverOptions{})
		if err == nil {
			return page, nil
		}
		last = err
		if attempt == maxAttempts || !isTransient(err) {
			return nil, fmt.Errorf("discover: %w", err)
		}
		if err := sleepBackoff(ctx, attempt); err != nil {
			return nil, err
		}
	}
	return nil, fmt.Errorf("discover: %w", last)
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
		if pb != nil && err == nil {
			return pb, nil
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
