package ohg

import (
	"context"
	"errors"
	"fmt"

	"github.com/beilunyang/openhongguo/adapters"
	"github.com/beilunyang/openhongguo/sdk"
	"github.com/beilunyang/openhongguo/sdk/model"
)

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

func (c *Client) Search(ctx context.Context, q string) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	return c.inner.Search(ctx, q, sdk.SearchOptions{})
}

func (c *Client) Discover(ctx context.Context) (*sdk.Page[model.SeriesSummary], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	return c.inner.Discover(ctx, sdk.DiscoverOptions{})
}

func (c *Client) ListEpisodes(ctx context.Context, seriesID string) (*sdk.Page[model.Episode], error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	return c.inner.ListEpisodes(ctx, seriesID, sdk.EpisodeOptions{})
}

// ResolvePlayback returns the playback model. Protected streams may still return
// a non-nil model together with sdk.ErrDRMProtected; callers should use sdk.ContentKey.
func (c *Client) ResolvePlayback(ctx context.Context, episodeID string) (*model.Playback, error) {
	if c.inner == nil {
		return nil, fmt.Errorf("ohg: nil client")
	}
	pb, err := c.inner.ResolvePlayback(ctx, episodeID, sdk.PlaybackOptions{})
	if pb != nil && errors.Is(err, sdk.ErrDRMProtected) {
		return pb, err
	}
	return pb, err
}
