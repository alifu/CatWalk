//
//  MainView.swift
//  CatWalk
//
//  Created by Annur Alif Ramadhoni  on 07/07/26.
//

import SwiftUI

struct MainView: View {
    @Environment(\.presentationMode) var presentationMode
    var onDismiss: () -> Void
    
    @StateObject private var viewModel = MainViewModel()
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                
                Button {
                    onDismiss()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Circle())
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            
            List(viewModel.logs, id: \.id) { log in
                MainCardView(log: log)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear { viewModel.reload() }
    }
}

#Preview {
    MainView(onDismiss: {})
}
