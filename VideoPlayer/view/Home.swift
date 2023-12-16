//
//  Home.swift
//  TestVideo
//
//  Created by Belet Developer on 05.12.2023.
//

import SwiftUI
import AVKit

struct Home: View {
    var size: CGSize
    var safeArea: EdgeInsets
    @ObservedObject private(set) var viewModel: ViewModel
    @State  var player: AVPlayer? = AVPlayer()
    @State private var showPlayerControllers: Bool =  false
    @State private var text: String = ""
//    @State private var isPlaying: Bool =  false
    @State private var isSeeking: Bool =  false
    @State private var isFinishingPlaying: Bool =  false
    @State private var timeoutTask: DispatchWorkItem?
//    @GestureState private var isDragging: Bool = false
//    @State private var bufferProgress: CGFloat = 0
//    @State private var progress: CGFloat = 0
//    @State private var lastDraggedProgress: CGFloat = 0
//    @State private var lastBufferProgress: CGFloat = 0
    @State private var isObserverAdded: Bool =  false
    @State private var thumbnailFrames: [UIImage] =  []
    @State private var draggingImage: UIImage?
    @State private var playerStatusObserver: NSKeyValueObservation?
    @State private var playerObserver: Any?
    @State private var audioIndex: Int = 1
//    @State private var loadedTimeRanges: [NSValue]
    var body: some View {
        VStack(spacing:0){
            let videoPlayerSize: CGSize = .init(width: size.width, height: size.height/3.5)
            
            ZStack{
                if  viewModel.player != nil {
                    CustomVideoPlayer(player: viewModel.player)
                        .overlay{
                            Rectangle()
                                .fill(.black.opacity(0.4))
                                .opacity(showPlayerControllers || viewModel.isDragging ? 1 : 0)
                                .animation(.easeInOut(duration: 0.35), value: viewModel.isDragging)
                                .overlay{
                                    PlayBackControls()
                                }
                        }
                        .overlay{
                            HStack(spacing: 60){
                                DoubleTapSeek(){
                                    let seconds = viewModel.player.currentTime().seconds - 15
                                    viewModel.player.seek(to: .init(seconds: seconds, preferredTimescale: 600))
                                }
                                DoubleTapSeek(isForward:true){
                                    let seconds = viewModel.player.currentTime().seconds + 15
                                    viewModel.player.seek(to: .init(seconds: seconds, preferredTimescale: 600))
                                }
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)){
                                showPlayerControllers.toggle()
                            }
                            if viewModel.isPlaying {
                                timeoutControls()
                            }
                        }
                        .overlay(alignment: .leading){
                            SeekerThumbnailView(videoPlayerSize)
                        }
                        .overlay(alignment: .bottom){
                            VideoSeekerView (videoPlayerSize)
                        }
                }
            } .frame(width: videoPlayerSize.width, height: videoPlayerSize.height)
            
            ResolutionSelectionControl()

//            ScrollView(.vertical, showsIndicators: false){
//                VStack(spacing: 10){
//                    ForEach(1...6, id:\.self){ index in
//                        GeometryReader{
//                            let size = $0.size
//                             
//                            Image("thumbnail_\(index)")
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(width: size.width, height: size.height)
//                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
//                        }
//                        .frame(height: 220)
//                    }
//                }
//                .padding(.horizontal, 15)
//                                    .padding(.top, 30)
//                                    .padding(.bottom, 15 + safeArea.bottom)
//            }
        }.padding(.top, safeArea.top)
            .onAppear{
                guard !isObserverAdded else {return}
                
                viewModel.listen()

                isObserverAdded = true
                playerStatusObserver = viewModel.player.observe(\.status, changeHandler: { player, _ in
                    if player.status == .readyToPlay {
                        generateThumbnailFrames()
                    }
                })
            }
            .onDisappear{
                playerStatusObserver?.invalidate()
            }
    }
    
    @ViewBuilder
    func VideoSeekerView (_ videoSize: CGSize) -> some View {
        ZStack(alignment: .leading){
            Rectangle()
                .fill(.gray)
            Rectangle()
                .fill(.white).opacity(0.6)
                .frame(width: max(size.width * viewModel.bufferProgress, 0))
            Rectangle()
                .fill(.red)
                .frame(width: max(size.width * viewModel.progress, 0))
            
        }
        .frame(height: showPlayerControllers || viewModel.isDragging ? 6 : 3)
        .onTapGesture { value in
            if let timeoutTask{
                timeoutTask.cancel()
            }
        
            let calculatedProgress = (value.x / videoSize.width)
            
            viewModel.progress = max(min(calculatedProgress, 1), 0)
            viewModel.lastDraggedProgress = viewModel.progress
            viewModel.lastBufferProgress = viewModel.bufferProgress
            if let currentPlayerItem = viewModel.player.currentItem {
                let totalDuration = currentPlayerItem.duration.seconds
                
                viewModel.player.seek(to: .init(seconds: totalDuration * viewModel.progress, preferredTimescale: 600))
            }
            
            if viewModel.isPlaying {
                timeoutControls()
            }
          }
        .overlay(alignment: .leading){
            Circle()
                .fill(.red)
                .frame(width: 15,height: 15)
                .scaleEffect(showPlayerControllers || viewModel.isDragging ? 1 : 0.001, anchor: viewModel.progress * size.width > 15 ? .trailing : .leading)
            // For More Dragging Space
                .frame(width: 50,height: 50)
                .contentShape(Rectangle())
                .offset(x:size.width * viewModel.progress)
                .gesture(
                    DragGesture()
                        .updating(viewModel.$isDragging, body: { _, out, _ in
                            out = true
                        })
                        .onChanged({ value in
                            if let timeoutTask{
                                timeoutTask.cancel()
                            }
                            
                            let translationX: CGFloat = value.translation.width
                            let calculatedProgress = (translationX / videoSize.width) + viewModel.lastDraggedProgress
                            
                            viewModel.progress = max(min(calculatedProgress, 1), 0)
//                            bufferProgress = max(min(calculatedProgress, 1), 0)
                            isSeeking = true
                            let dragIndex = Int(viewModel.progress / 0.01)
                            if thumbnailFrames.indices.contains(dragIndex){
                                draggingImage = thumbnailFrames[dragIndex]
                            }
                        })
                        .onEnded({ value in
                            viewModel.lastDraggedProgress = viewModel.progress
                            viewModel.lastBufferProgress = viewModel.bufferProgress
                            if let currentPlayerItem = viewModel.player.currentItem {
                                let totalDuration = currentPlayerItem.duration.seconds
                                
                                viewModel.player.seek(to: .init(seconds: totalDuration * viewModel.progress, preferredTimescale: 600))
                            }
                            
                            if viewModel.isPlaying {
                                timeoutControls()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
                                isSeeking = false
                            }
                        })
                )
                .offset(x: viewModel.progress * videoSize.width > 15 ? -15 : 0 )
                .frame(width: 15,height: 15)
        }
        
    }
    
    @ViewBuilder
    func SeekerThumbnailView(_ videoSize: CGSize) -> some View {
        let thumbSize: CGSize = .init(width: 175, height: 100)
        ZStack{
            if let draggingImage {
                Image(uiImage: draggingImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: thumbSize.width, height: thumbSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(alignment: .bottom, content: {
                        if let currentItem = viewModel.player.currentItem{
                            Text(CMTime(seconds: viewModel.progress * currentItem.duration.seconds, preferredTimescale: 600).toTimeString())
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .offset(y:25)
                        }
                    })
                    .overlay{
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.white, lineWidth: 2)
                    }
            } else {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.black)
                    .overlay{
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.white, lineWidth: 2)
                    }
            }
        }
        .frame(width: thumbSize.width, height: thumbSize.height)
        .opacity(viewModel.isDragging ? 1 : 0)
        .offset(x:viewModel.progress * (videoSize.width - thumbSize.width))
        .offset(x: 10)
    }
    
    @ViewBuilder
    func PlayBackControls() -> some View {
        HStack(spacing:25){
            PlayBackButton(iconName:"backward.end.fill")
                .disabled(true)
                .opacity(0.6)
            Button(action: {
                if isFinishingPlaying{
                    isFinishingPlaying = false
                    viewModel.player.seek(to: .zero)
                    viewModel.progress = .zero
                    viewModel.lastDraggedProgress = .zero
                }
                if viewModel.isPlaying {
                    viewModel.player.pause()
                    if let timeoutTask {
                        timeoutTask.cancel()
                    }
                } else {
                    viewModel.player.play()
                    timeoutControls()
                }
                withAnimation(.easeInOut(duration: 0.2)){
                    viewModel.isPlaying.toggle()
                }
            }) {
                Image(systemName: isFinishingPlaying ? "arrow.clockwise" : (viewModel.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(15)
                    .background{
                        Circle()
                            .fill(.black.opacity(0.35))
                    }
            }.scaleEffect(1.1)
            PlayBackButton(iconName:"forward.end.fill")
                .disabled(true)
                .opacity(0.6)
            
        }
        .opacity(showPlayerControllers && !viewModel.isDragging ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: showPlayerControllers && !viewModel.isDragging )
    }
    @ViewBuilder
    func  ResolutionSelectionControl()-> some View  {
        VStack{
            Text("(\(text))")
            Button(action: {
                viewModel.auto()
                text = "auto"
            }, label: {Text("auto")})
            Button(action: {
                viewModel.max()
                text = "max"
            }, label: {Text("max")})
            Button(action: {
                viewModel.min()
                text = "min"
            }, label: {Text("min")})
        
            Picker("Appearance", selection: $viewModel.selectedResolution) {
                ForEach(viewModel.resolutions, id: \.self) {
                    Text($0.description)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedResolution) { newValue in
                viewModel.changedResolution()
                text = "\(newValue)"
                print("Selected option changed to: \(newValue)")
            }
        }
    }
    
    @ViewBuilder
    func PlayBackButton(iconName:String ) -> some View {
        
        Button(action: {
        
        }) {
            Image(systemName: iconName)
                .font(.title2)
//                .fontWeight(.ultraLight)
                .foregroundColor(.white)
                .padding(15)
                .background{
                    Circle()
                        .fill(.black.opacity(0.35))
                }
        }
    }
    
    func timeoutControls(){
        if let timeoutTask{
            timeoutTask.cancel()
        }
        timeoutTask = .init(block: {
            withAnimation(.easeInOut(duration: 0.35)){
                showPlayerControllers = false
            }
        })
        
        if let timeoutTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeoutTask)
        }
    }
    
    func generateThumbnailFrames(){
        Task.detached{
            guard let asset = await player?.currentItem?.asset else {return}
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
}
//
//#Preview {
//    ContentView()
//}

