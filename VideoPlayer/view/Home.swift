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
    @State private var text: String = ""
    @State private var timeoutTask: DispatchWorkItem?
    @State private var thumbnailFrames: [UIImage] =  []
    @State private var draggingImage: UIImage?
    var body: some View {
        VStack(spacing:0){
            let videoPlayerSize: CGSize = .init(width: size.width, height: size.height/3.5)
            ZStack{
                CustomVideoPlayer(player: viewModel.player)
                    .overlay{
                        Rectangle()
                            .fill(.black.opacity(0.4))
                            .opacity(viewModel.showPlayerControllers || viewModel.isDragging ? 1 : 0)
                            .animation(.easeInOut(duration: 0.35), value: viewModel.isDragging)
                            .overlay{
                                PlayBackControls()
                            }
                    }
                    .overlay{
                        HStack(spacing: 60){
                            DoubleTapSeek(){
                                viewModel.doubleTab()
                            }
                            DoubleTapSeek(isForward:true){
                                viewModel.doubleTab(isForward:true)
                            }
                        }
                    }
                    .onTapGesture {
                        viewModel.onTapScreen()
                    }
                    .overlay(alignment: .leading){
                        SeekerThumbnailView(videoPlayerSize)
                    }
                    .overlay(alignment: .bottom){
                        VideoSeekerView (videoPlayerSize)
                    }
            } .frame(width: videoPlayerSize.width, height: videoPlayerSize.height)
            ResolutionSelectionControl()
        }.padding(.top, safeArea.top)
            .onAppear{
                viewModel.onAppear()
            }
            .onDisappear{
                viewModel.onDisappear()
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
        .frame(height: viewModel.showPlayerControllers || viewModel.isDragging ? 6 : 3)
        .onTapGesture { value in
            viewModel.onTabGestureVideoSeekerView(value: value, videoSize: videoSize)
        }
        .overlay(alignment: .leading){
            Circle()
                .fill(.red)
                .frame(width: 15,height: 15)
                .scaleEffect(viewModel.showPlayerControllers || viewModel.isDragging ? 1 : 0.001, anchor: viewModel.progress * size.width > 15 ? .trailing : .leading)
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
                            viewModel.onChangedDragGesture(value:value, videoSize: videoSize)
                        })
                        .onEnded({ value in
                            viewModel.onEndedDragGesture(value:value)
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
                viewModel.playPouse()
            }) {
                Image(systemName: viewModel.isFinishingPlaying ? "arrow.clockwise" : (viewModel.isPlaying ? "pause.fill" : "play.fill"))
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
        .opacity(viewModel.showPlayerControllers && !viewModel.isDragging ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showPlayerControllers && !viewModel.isDragging )
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
        Button(action: {}) {
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
}
//
//#Preview {
//    ContentView()
//}
