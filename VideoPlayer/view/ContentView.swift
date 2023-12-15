//
//  ContentView.swift
//  VideoPlayer
//
//  Created by Belet Developer on 12.12.2023.
//  Copyright © 2023 Ivano Bilenchi. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    let factory: AppFactory
    var body: some View{
        GeometryReader{
            let size = $0.size
            let safeArea = $0.safeAreaInsets
            Home(size: size, safeArea: safeArea,viewModel: .init(factory: factory))
                .ignoresSafeArea()
        }.preferredColorScheme(.dark)
    }
}
#Preview {
    ContentView(factory:AppFactory())
}
