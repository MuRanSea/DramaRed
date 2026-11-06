package api

import (
	"errors"
	"net/http"
	"strings"

	"github.com/beilunyang/openhongguo/sdk"
)

// classifyUpstream maps openhongguo / transport failures to an HTTP status and
// a user-facing Chinese message. Historically every ohg error was returned as
// 502 Bad Gateway, which made ErrAnonymousLimited (empty recommend tab) look
 // like a CDN/gateway outage even though Search still worked.
func classifyUpstream(err error) (status int, message string) {
	if err == nil {
		return http.StatusInternalServerError, "未知错误"
	}
	raw := err.Error()
	low := strings.ToLower(raw)

	switch {
	case errors.Is(err, sdk.ErrAnonymousLimited) || strings.Contains(low, "anonymous response was empty"):
		return http.StatusServiceUnavailable, "推荐接口暂时没有返回内容（匿名设备空页）。可点重试，或先用搜索找剧"
	case errors.Is(err, sdk.ErrRateLimited) || strings.Contains(low, "429"):
		return http.StatusTooManyRequests, "请求过于频繁，请稍后再试"
	case errors.Is(err, sdk.ErrChallengeRequired):
		return http.StatusForbidden, "上游要求验证，当前匿名客户端无法继续"
	case errors.Is(err, sdk.ErrDeviceRejected):
		return http.StatusServiceUnavailable, "匿名设备被拒绝，请重启客户端以重新注册"
	case errors.Is(err, sdk.ErrAuthenticationRequired):
		return http.StatusUnauthorized, "需要登录才能访问该内容"
	case errors.Is(err, sdk.ErrContentUnavailable) || errors.Is(err, sdk.ErrAlbumUnavailable):
		return http.StatusNotFound, "内容不可用或不存在"
	case errors.Is(err, sdk.ErrTransport) ||
		strings.Contains(low, "connection refused") ||
		strings.Contains(low, "timeout") ||
		strings.Contains(low, "tls handshake"):
		return http.StatusBadGateway, "连接上游短剧服务失败，请检查网络后重试"
	}

	var api *sdk.APIError
	if errors.As(err, &api) {
		switch {
		case api.HTTPStatus == 502, api.HTTPStatus == 503, api.HTTPStatus == 504:
			return http.StatusBadGateway, "上游短剧服务网关异常，请稍后重试"
		case api.HTTPStatus >= 500:
			return http.StatusBadGateway, "上游短剧服务暂时不可用，请稍后重试"
		case api.HTTPStatus == 429:
			return http.StatusTooManyRequests, "请求过于频繁，请稍后再试"
		}
	}

	if strings.Contains(low, "bad gateway") || strings.Contains(low, "502") {
		return http.StatusBadGateway, "上游短剧服务暂时不可用（网关错误），请稍后重试"
	}
	return http.StatusBadGateway, "获取内容失败，请稍后重试"
}
