//
//  ContentView.swift
//  DemoSwiftUI
//
//  Created by Annur Alif Ramadhoni  on 25/06/26.
//

import SwiftUI
import Combine
import CatWalk

struct Product: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
}

struct ProductsResponse: Codable {
    let products: [Product]
}

class ProductsViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProducts() {
        isLoading = true
        errorMessage = nil
        let url = URL(string: "https://dummyjson.com/products")!
        session.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data"
                    self.isLoading = false
                    return
                }
                do {
                    let response = try JSONDecoder().decode(ProductsResponse.self, from: data)
                    self.products = response.products
                } catch {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var viewModel: ProductsViewModel
    @State private var didAppear = false
    @State private var showsInspector = false

    init(session: URLSession = .shared) {
        _viewModel = StateObject(wrappedValue: ProductsViewModel(session: session))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                List(viewModel.products) { product in
                    VStack(alignment: .leading) {
                        Text(product.title).bold()
                        Text(product.description).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
        }
        .overlay(alignment: .bottomLeading) {
            HStack {
                Button("Inspector") { showsInspector = true }
                Button("Background download") { BackgroundDownloader.shared.download() }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .catWalk(isPresented: $showsInspector)
        .onAppear {
            if !didAppear {
                viewModel.fetchProducts()
                didAppear = true
            }
        }
    }
}

#Preview {
    ContentView()
}
