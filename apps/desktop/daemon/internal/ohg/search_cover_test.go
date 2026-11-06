package ohg

import (
	"context"
	"testing"

	"github.com/beilunyang/openhongguo/sdk"
	"github.com/beilunyang/openhongguo/sdk/model"
)

func TestEnrichSearchCovers_nilSafe(t *testing.T) {
	c := &Client{}
	c.enrichSearchCovers(context.Background(), nil)
	c.enrichSearchCovers(context.Background(), &sdk.Page[model.SeriesSummary]{})
	c.enrichSearchCovers(context.Background(), &sdk.Page[model.SeriesSummary]{
		Items: []model.SeriesSummary{{ID: "1", Title: "t", CoverURL: "http://x"}},
	})
}
