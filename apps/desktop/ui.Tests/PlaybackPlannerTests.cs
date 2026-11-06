using DramaRed.UI.Models;
using DramaRed.UI.Services;
using Xunit;

namespace DramaRed.UI.Tests;

public class PlaybackPlannerTests
{
    [Fact]
    public void PickStream_prefers_named_quality_then_highest()
    {
        var streams = new[]
        {
            new PlaybackStream { Definition = "360p", Height = 360, Url = "u360" },
            new PlaybackStream { Definition = "720p", Height = 720, Url = "u720" },
            new PlaybackStream { Definition = "1080p", Height = 1080, Url = "u1080" },
        };

        Assert.Equal("u1080", PlaybackPlanner.PickStream(streams, "自动")!.Url);
        Assert.Equal("u720", PlaybackPlanner.PickStream(streams, "720p")!.Url);
        Assert.Null(PlaybackPlanner.PickStream(Array.Empty<PlaybackStream>(), "自动"));
    }

    [Fact]
    public void Next_and_previous_walk_episode_list()
    {
        var eps = new List<EpisodeItem>
        {
            new() { Id = "a", Number = 1, Title = "一" },
            new() { Id = "b", Number = 2, Title = "二" },
            new() { Id = "c", Number = 3, Title = "三" },
        };

        Assert.Equal("b", PlaybackPlanner.Next(eps, "a")!.Id);
        Assert.Equal("c", PlaybackPlanner.Next(eps, "b")!.Id);
        Assert.Null(PlaybackPlanner.Next(eps, "c"));
        Assert.Equal("a", PlaybackPlanner.Previous(eps, "b")!.Id);
        Assert.Null(PlaybackPlanner.Previous(eps, "a"));
        Assert.Null(PlaybackPlanner.Next(eps, "missing"));
    }
}

public class EpisodeLabelTests
{
    [Fact]
    public void ListLabel_does_not_double_episode_number_title()
    {
        var ep = new EpisodeItem { Id = "e1", Number = 1, Title = "第1集" };
        Assert.Equal("第 1 集", ep.ListLabel);
        Assert.Equal("第 1 集", ep.ChipLabel);

        var spaced = new EpisodeItem { Id = "e2", Number = 56, Title = "第 56 集" };
        Assert.Equal("第 56 集", spaced.ListLabel);

        var named = new EpisodeItem { Id = "e3", Number = 2, Title = "转折" };
        Assert.Equal("第 2 集 · 转折", named.ListLabel);
    }
}
