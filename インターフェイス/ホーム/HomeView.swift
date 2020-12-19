//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var settings: Settings
    @StateObject var store = PopularItemsStore()
    
    var body: some View {
        NavigationView { Group {
            if !store.popularItems.isEmpty {
                ScrollView { LazyVStack {
                    ForEach(store.popularItems) { item in NavigationLink(destination: DetailView(manga: item)) {
                        let imageContainer = ImageContainer(from: item.coverURL, type: .cover, 110)
                        MangaSummaryRow(container: imageContainer, manga: item)
                    }
                }}
                .padding()}
                .transition(AnyTransition.opacity.animation(.linear(duration: 0.5)))
            } else {
                LoadingView()
            }}
            .navigationBarTitle("人気")
        }
        .navigationBarHidden(settings.navBarHidden)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            settings.navBarHidden = false
            
            store.fetchPopularItems()
        }
    }
}

private struct MangaSummaryRow: View {
    @StateObject var container: ImageContainer
    let manga: Manga
    
    var body: some View {
        HStack {
            container.image
                .resizable()
                .frame(width: 70, height: 110)
            VStack(alignment: .leading) {
                Text(manga.title)
                    .lineLimit(1)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(manga.uploader)
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack {
                    RatingView(rating: manga.rating)
                }
                HStack(alignment: .bottom) {
                    Text(manga.translatedCategory)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.init(top: 1, leading: 3, bottom: 1, trailing: 3))
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .foregroundColor(Color(manga.color))
                        )
                    Spacer()
                    Text(manga.publishedTime)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 1)
            }.padding(10)
        }
        .background(Color(.systemGray6))
        .cornerRadius(3)
    }
}
