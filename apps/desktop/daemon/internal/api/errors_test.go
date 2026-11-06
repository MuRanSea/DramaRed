package api

import (
	"errors"
	"net/http"
	"testing"

	"github.com/beilunyang/openhongguo/sdk"
)

func TestClassifyUpstream_anonymousLimited_isNotMasqueradedAsOnly502Text(t *testing.T) {
	status, msg := classifyUpstream(sdk.ErrAnonymousLimited)
	if status != http.StatusServiceUnavailable {
		t.Fatalf("status=%d want 503", status)
	}
	if msg == "" || contains(msg, "502") {
		t.Fatalf("message should explain empty recommend, not 502: %q", msg)
	}
	if !contains(msg, "推荐") && !contains(msg, "空") {
		t.Fatalf("message=%q", msg)
	}
}

func TestClassifyUpstream_realAPIError502(t *testing.T) {
	status, msg := classifyUpstream(&sdk.APIError{HTTPStatus: 502, Message: "HTTP request failed"})
	if status != http.StatusBadGateway {
		t.Fatalf("status=%d", status)
	}
	if msg == "" {
		t.Fatal("empty message")
	}
}

func TestClassifyUpstream_wrappedAnonymous(t *testing.T) {
	err := errors.New("discover: openhongguo: anonymous response was empty")
	status, msg := classifyUpstream(err)
	// string-only wrap may not errors.Is, but message contains the phrase
	if status != http.StatusServiceUnavailable && status != http.StatusBadGateway {
		t.Fatalf("status=%d msg=%q", status, msg)
	}
	if status == http.StatusServiceUnavailable && contains(msg, "网关") {
		t.Fatalf("should not say 网关 for anonymous empty: %q", msg)
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (s == sub || len(sub) == 0 ||
		(len(s) > 0 && (func() bool {
			for i := 0; i+len(sub) <= len(s); i++ {
				if s[i:i+len(sub)] == sub {
					return true
				}
			}
			return false
		})()))
}
