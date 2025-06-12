//
//  ResultView.swift
//  tesposturbasket
//
//  Created by Muhamad Alif Anwar on 12/06/25.
//

import SwiftUI

struct ResultView: View {
    let images: [UIImage]

    var body: some View {
        ScrollView {
            VStack {
                ForEach(images.indices, id: \.self) { index in
                    Image(uiImage: images[index])
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Hasil Deteksi Bola")
    }
}



