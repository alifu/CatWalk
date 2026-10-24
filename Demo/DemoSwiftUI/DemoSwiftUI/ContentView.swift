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

    func fetchProducts() {
        isLoading = true
        errorMessage = nil
        let url = URL(string: "https://dummyjson.com/products")!
        URLSession.shared.dataTask(with: url) { data, response, error in
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
    @ObservedObject private var viewModel: ProductsViewModel = ProductsViewModel()
    @State private var didAppear = false

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
