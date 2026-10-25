#if CATWALK_ENABLED
//
//  CWFilterBar.swift
//  CatWalk
//

import SwiftUI

/// Method, status class, mocked-only and host filters as horizontally scrolling chips.
struct CWFilterBar: View {

    @ObservedObject var viewModel: CWListViewModel

    private static let methods = ["GET", "POST", "PUT", "PATCH", "DELETE"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.methods, id: \.self) { method in
                    CWChip(title: method, isSelected: viewModel.filter.methods.contains(method)) {
                        viewModel.toggle(method: method)
                    }
                }
                ForEach(CWStatusClass.allCases, id: \.self) { statusClass in
                    CWChip(title: statusClass.title, isSelected: viewModel.filter.statusClasses.contains(statusClass)) {
                        viewModel.toggle(statusClass: statusClass)
                    }
                }
                CWChip(title: "Mocked", isSelected: viewModel.filter.mockedOnly) {
                    viewModel.filter.mockedOnly.toggle()
                }
                hostMenu
                sourceMenu
            }
            .padding(.horizontal)
        }
    }

    private var sourceMenu: some View {
        Menu {
            Button("All sources") { viewModel.filter.source = nil }
            ForEach(CWTransaction.Source.allCases, id: \.self) { source in
                Button(source.title) { viewModel.filter.source = source }
            }
        } label: {
            Label(viewModel.filter.source?.title ?? "Source", systemImage: "tray.2")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(viewModel.filter.source == nil ? .primary : .white)
                .background(viewModel.filter.source == nil ? Color(.secondarySystemFill) : .accentColor, in: Capsule())
        }
    }

    private var hostMenu: some View {
        Menu {
            Button("All hosts") { viewModel.filter.host = nil }
            ForEach(viewModel.hosts, id: \.self) { host in
                Button(host) { viewModel.filter.host = host }
            }
        } label: {
            Label(viewModel.filter.host ?? "Host", systemImage: "network")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundColor(viewModel.filter.host == nil ? .primary : .white)
                .background(viewModel.filter.host == nil ? Color(.secondarySystemFill) : .accentColor, in: Capsule())
        }
    }
}
#endif
