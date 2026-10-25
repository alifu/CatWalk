//
//  MediaDemoView.swift
//  DemoSwiftUI
//

import AVKit
import SwiftUI

/// Plays Apple's public HLS sample. CatWalk lists the playlist and segment requests ("MEDIA" rows)
/// on iOS 18+, and one playback row per session before that.
struct MediaDemoView: View {

    private static let stream = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!

    @State private var player = AVPlayer(url: stream)

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player.play() }
            .onDisappear { player.pause() }
    }
}
