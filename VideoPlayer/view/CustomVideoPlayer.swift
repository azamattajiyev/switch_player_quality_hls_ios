//
//  CustomVideoPlayer.swift
//  TestVideo
//
//  Created by Belet Developer on 05.12.2023.
//
import AVKit
import SwiftUI

struct CustomVideoPlayer: UIViewControllerRepresentable{
    var player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
//        controller.edgesForExtendedLayout = .init(rawValue: 0)

        controller.player = player
        controller.showsPlaybackControls = false

        return controller
    }
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
    }
}
