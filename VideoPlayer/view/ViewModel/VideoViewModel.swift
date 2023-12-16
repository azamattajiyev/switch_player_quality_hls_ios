//
//  VideoViewModel.swift
//  VideoPlayer
//
//  Created by Belet Developer on 12.12.2023.
//  Copyright © 2023 Ivano Bilenchi. All rights reserved.
//

import AVKit
import SwiftUI


extension Home{
    class ViewModel: ObservableObject, StreamProxyDelegate  {
        lazy var proxy: StreamProxy = {
            return StreamProxy(remotePlaylistUrl: playlistUrl)
        }()
        let playlistUrl = URL(string: "https://bv-storage-staging.belet.me/videos/UC8yUlNkVO5ak_nnOW6bsaFQ/kDuUS9g77R4/master.m3u8")!
        @Published var player =  AVPlayer()
        @Published var showPlayerControllers: Bool =  false
        @Published var isPlaying: Bool =  false
        @Published var isSeeking: Bool =  false
        @Published var isFinishingPlaying: Bool =  false
        @Published var timeoutTask: DispatchWorkItem?
        @GestureState var isDragging: Bool = false
        @Published var bufferProgress: CGFloat = 0
        @Published var progress: CGFloat = 0
        @Published var lastDraggedProgress: CGFloat = 0
        @Published var lastBufferProgress: CGFloat = 0
        @Published var isObserverAdded: Bool =  false
        @Published var thumbnailFrames: [UIImage] =  []
        @Published var draggingImage: UIImage?
        @Published var playerStatusObserver: NSKeyValueObservation?
        @Published var playerObserver: Any?
        @Published var audioIndex: Int = 1
        init() {
            proxy.start(withPort: AppConfig.serverPort, bonjourName: nil)
            if let url = proxy.localPlaylistUrl {
                let playerItem = AVPlayerItem(url: url)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.currentItem?.preferredForwardBufferDuration = 10
                proxy.proxyDelegate = self
            }
        }
        func onAppear(){
            guard !isObserverAdded else {return}
            self.player.addPeriodicTimeObserver(forInterval: .init(seconds: 1, preferredTimescale: 600), queue: .main, using: { time in
                if let currentPlayerItem = self.player.currentItem{
                    let totalDuration = currentPlayerItem.duration.seconds
                    print(self.player.currentItem?.presentationSize)
                    let loadedTimeRanges: [NSValue] = currentPlayerItem.loadedTimeRanges

                    guard let timeRange = loadedTimeRanges.first?.timeRangeValue else { return }

//                           let startTime = CMTimeGetSeconds(timeRange.start)
//                           let loadedDuration = CMTimeGetSeconds(timeRange.duration)
                       let end = CMTimeGetSeconds(timeRange.end)
                    let currentDuration = self.player.currentTime().seconds
                    let calculationProgress = currentDuration / totalDuration
                    let calculationBufferProgress = end / totalDuration
                    if !self.isSeeking {
                        self.progress = calculationProgress
                        self.bufferProgress = calculationBufferProgress
                        self.lastDraggedProgress = self.progress
                    }
                    
                    if calculationProgress == 1 {
                        self.isFinishingPlaying = true
                        self.isPlaying = false
                        
                    }
                }
            })
            isObserverAdded = true
            playerStatusObserver = player.observe(\.status, changeHandler: { player, _ in
                if player.status == .readyToPlay {
                    self.generateThumbnailFrames()
                }
            })
        }
        
        func onDisappear(){
            playerStatusObserver?.invalidate()
        }
        func doubleTab(isForward:Bool = false){
            player.seek(to: .init(seconds: player.currentTime().seconds + (isForward ? 10 : -10) , preferredTimescale: 600))
        }
        func onTapScreen() {
            withAnimation(.easeInOut(duration: 0.35)){
                showPlayerControllers.toggle()
            }
            if isPlaying {
                timeoutControls()
            }
        }
        
        func timeoutControls(){
            if let timeoutTask{
                timeoutTask.cancel()
            }
            timeoutTask = .init(block: {
                withAnimation(.easeInOut(duration: 0.35)){
                    self.showPlayerControllers = false
                }
            })
            
            if let timeoutTask {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeoutTask)
            }
        }
        
        func playPouse(){
            if isFinishingPlaying{
                isFinishingPlaying = false
                player.seek(to: .zero)
                progress = .zero
                lastDraggedProgress = .zero
            }
            if isPlaying {
                player.pause()
                if let timeoutTask {
                    timeoutTask.cancel()
                }
            } else {
                player.play()
                timeoutControls()
            }
            withAnimation(.easeInOut(duration: 0.2)){
                isPlaying.toggle()
            }
        }
        func onEndedDragGesture(value: DragGesture.Value){
            lastDraggedProgress = progress
            lastBufferProgress = bufferProgress
            if let currentPlayerItem = player.currentItem {
                let totalDuration = currentPlayerItem.duration.seconds
                player.seek(to: .init(seconds: totalDuration * progress, preferredTimescale: 600))
            }
            
            if isPlaying {
                timeoutControls()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                self.isSeeking = false
            }
        }
        func onChangedDragGesture(value: DragGesture.Value, videoSize: CGSize){
            if let timeoutTask{
                timeoutTask.cancel()
            }
            
            let translationX: CGFloat = value.translation.width
            let calculatedProgress = (translationX / videoSize.width) + lastDraggedProgress
            
            progress = Swift.max(Swift.min(calculatedProgress, 1), 0)
            isSeeking = true
            let dragIndex = Int(progress / 0.01)
            if thumbnailFrames.indices.contains(dragIndex){
                draggingImage = thumbnailFrames[dragIndex]
            }
        }
        func onTabGestureVideoSeekerView (value: CGPoint, videoSize: CGSize){
            if let timeoutTask{
                timeoutTask.cancel()
            }
            let calculatedProgress = (value.x / videoSize.width)
            
            progress = Swift.max(Swift.min(calculatedProgress, 1), 0)
            lastDraggedProgress = progress
            lastBufferProgress = bufferProgress
            if let currentPlayerItem = player.currentItem {
                let totalDuration = currentPlayerItem.duration.seconds
                
                player.seek(to: .init(seconds: totalDuration * progress, preferredTimescale: 600))
            }
            
            if isPlaying {
                timeoutControls()
            }
        }
        func generateThumbnailFrames(){
            Task.detached{
                guard let asset = self.player.currentItem?.asset else {return}
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                
                generator.maximumSize = .init(width:250, height: 250)
                do {
                    let totalDuration = try await asset.load(.duration).seconds
                    var frameTimes: [CMTime] = []
                    
                    for progress in stride(from: 0, to: 1, by: 0.01){
                        let time = CMTime(seconds: progress * totalDuration, preferredTimescale: 600)
                        frameTimes.append(time)
                    }
                    
    //                for await result in generator.images(for:frameTimes) {
    //                    let cgImage = try result.image
    //                    await MainActor.run ( body:{
    //                        thumbnailFrames.append(UIImage(cgImage: cgImage))
    //                    })
    //                }
                } catch {
                    print(error.localizedDescription)
                }
               
            }
        }
        // MARK: Resolution
        
        @Published var resolutions: [Resolution] = [.zero]
        
        @Published var selectedResolution: Resolution = .zero
        
        var resolutionTapHandler: ((_ newResolution: Resolution) -> Void)?
        var customTapHandler: ((_ num: Int) -> Void)?
        
        func auto() {
            customTapHandler?(0)
        }
        func min() {
            customTapHandler?(1)
        }
        func max() {
            customTapHandler?(2)
        }
        func changedResolution() {
            print(selectedResolution)
            resolutionTapHandler?(selectedResolution)
        }
        
        func streamProxy(_ proxy: StreamProxy, didReceiveMainPlaylist playlist: Playlist) {
            guard let playlist = playlist as? MasterPlaylist else { return }
            let resolutions = Array<Resolution>(playlist.mediaPlaylists.values.compactMap({ $0.resolution })).sorted()
            if !resolutions.isEmpty {
          
                proxy.policy = FixedQualityPolicy(quality: .withResolution(selectedResolution))
               
                self.resolutions = resolutions
                self.resolutionTapHandler = { (res) in
                    proxy.policy = FixedQualityPolicy(quality: .withResolution(res))
                }
                self.customTapHandler = { (num) in
                    switch num {
                        case 1:
                           return  proxy.policy = FixedQualityPolicy(quality: .min)
                    
                        case 2:
                            return  proxy.policy = FixedQualityPolicy(quality: .max)
                    default :
                        return proxy.policy = FixedQualityPolicy(quality: .withResolution(.zero))
                    
                    }
                    
                }
            }
        }
    }
}

