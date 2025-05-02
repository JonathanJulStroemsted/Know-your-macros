//
//  LaunchScreen.swift
//  Know your macros
//
//  Created by Jonathan Strømsted on 02/05/2025.
//

import SwiftUI

 struct LaunchScreen: View {
     var body: some View {
         ZStack {
             Color.white.ignoresSafeArea()
             Image("LaunchImage")
                 .resizable()
                 .scaledToFit()
                 .frame(maxWidth: .infinity, maxHeight: .infinity)
         }
     }
 }
