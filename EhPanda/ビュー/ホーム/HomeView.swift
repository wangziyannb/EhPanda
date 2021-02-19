//
//  HomeView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    var homeInfo: AppState.HomeInfo {
        store.appState.homeInfo
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    var environmentBinding: Binding<AppState.Environment> {
        $store.appState.environment
    }
    var settings: AppState.Settings {
        store.appState.settings
    }
    var setting: Setting? {
        settings.setting
    }
    var accentColor: Color? {
        setting?.accentColor
    }
    var historyItems: [Manga] {
        var items = homeInfo.historyItems?
            .compactMap({ $0.value })
            .filter({ $0.lastOpenTime != nil })
        items?.sort {
            $0.lastOpenTime ?? Date()
                > $1.lastOpenTime ?? Date()
        }
        return items ?? []
    }
    var navigationBarTitle: String {
        if let user = settings.user,
           environment.favoritesIndex != -1,
           environment.homeListType == .favorites
        {
            return user.getFavNameFrom(environment.favoritesIndex)
        } else {
            return environment.homeListType.rawValue.lString()
        }
    }
    
    var conditionalList: some View {
        Group {
            switch environment.homeListType {
            case .search:
                GenericList(
                    items: homeInfo.searchItems,
                    loadingFlag: homeInfo.searchLoading,
                    notFoundFlag: homeInfo.searchNotFound,
                    loadFailedFlag: homeInfo.searchLoadFailed,
                    moreLoadingFlag: homeInfo.moreSearchLoading,
                    moreLoadFailedFlag: homeInfo.moreSearchLoadFailed,
                    fetchAction: fetchSearchItems,
                    loadMoreAction: fetchMoreSearchItems
                )
            case .frontpage:
                GenericList(
                    items: homeInfo.frontpageItems,
                    loadingFlag: homeInfo.frontpageLoading,
                    notFoundFlag: homeInfo.frontpageNotFound,
                    loadFailedFlag: homeInfo.frontpageLoadFailed,
                    moreLoadingFlag: homeInfo.moreFrontpageLoading,
                    moreLoadFailedFlag: homeInfo.moreFrontpageLoadFailed,
                    fetchAction: fetchFrontpageItems,
                    loadMoreAction: fetchMoreFrontpageItems
                )
            case .popular:
                GenericList(
                    items: homeInfo.popularItems,
                    loadingFlag: homeInfo.popularLoading,
                    notFoundFlag: homeInfo.popularNotFound,
                    loadFailedFlag: homeInfo.popularLoadFailed,
                    moreLoadingFlag: false,
                    moreLoadFailedFlag: false,
                    fetchAction: fetchPopularItems
                )
            case .watched:
                GenericList(
                    items: homeInfo.watchedItems,
                    loadingFlag: homeInfo.watchedLoading,
                    notFoundFlag: homeInfo.watchedNotFound,
                    loadFailedFlag: homeInfo.watchedLoadFailed,
                    moreLoadingFlag: homeInfo.moreWatchedLoading,
                    moreLoadFailedFlag: homeInfo.moreWatchedLoadFailed,
                    fetchAction: fetchWatchedItems,
                    loadMoreAction: fetchMoreWatchedItems
                )
            case .favorites:
                GenericList(
                    items: homeInfo.favoritesItems[
                        environment.favoritesIndex
                    ],
                    loadingFlag: homeInfo.favoritesLoading[
                        environment.favoritesIndex
                    ] ?? false,
                    notFoundFlag: homeInfo.favoritesNotFound[
                        environment.favoritesIndex
                    ] ?? false,
                    loadFailedFlag: homeInfo.favoritesLoadFailed[
                        environment.favoritesIndex
                    ] ?? false,
                    moreLoadingFlag: homeInfo.moreFavoritesLoading[
                        environment.favoritesIndex
                    ] ?? false,
                    moreLoadFailedFlag: homeInfo.moreFavoritesLoadFailed[
                        environment.favoritesIndex
                    ] ?? false,
                    fetchAction: fetchFavoritesItems,
                    loadMoreAction: fetchMoreFavoritesItems
                )
            case .downloaded:
                NotFoundView(retryAction: nil)
            case .history:
                GenericList(
                    items: historyItems,
                    loadingFlag: false,
                    notFoundFlag: false,
                    loadFailedFlag: false,
                    moreLoadingFlag: false,
                    moreLoadFailedFlag: false
                )
            }
        }
    }
    
    var navigationBarItem: some View {
        Group {
            if let user = settings.user,
               let names = user.favoriteNames,
               environment.homeListType == .favorites
            {
                Menu {
                    ForEach(-1..<names.count - 1) { index in
                        Button(action: {
                            onFavMenuSelect(index)
                        }, label: {
                            HStack {
                                Text(user.getFavNameFrom(index))
                                if index == environment.favoritesIndex {
                                    Image(systemName: "checkmark")
                                }
                            }
                        })
                    }
                } label: {
                    Image(systemName: "square.2.stack.3d.top.fill")
                        .foregroundColor(.primary)
                }

            }
        }
    }
    
    // MARK: HomeView本体
    var body: some View {
        NavigationView {
            conditionalList
                .onChange(
                    of: environment.homeListType,
                    perform: onHomeListTypeChange
                )
                .onChange(
                    of: environment.favoritesIndex,
                    perform: onFavoritesIndexChange
                )
                .onAppear(perform: onListAppear)
                .navigationBarTitle(navigationBarTitle)
                .navigationBarItems(trailing:
                    navigationBarItem
                )
            
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(item: environmentBinding.homeViewSheetState) { item in
            switch item {
            case .setting:
                SettingView()
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            case .filter:
                FilterView()
                    .environmentObject(store)
                    .accentColor(accentColor)
                    .preferredColorScheme(colorScheme)
                    .blur(radius: environment.blurRadius)
                    .allowsHitTesting(environment.isAppUnlocked)
            }
        }
    }
    
    func onListAppear() {
        if settings.user == nil {
            store.dispatch(.initiateUser)
        }
        if setting == nil {
            store.dispatch(.initiateSetting)
        }
        if settings.user?.displayName?.isEmpty != false {
            fetchUserInfo()
        }
        fetchFavoriteNames()
        fetchFrontpageItemsIfNeeded()
    }
    func onHomeListTypeChange(_ type: HomeListType) {
        switch type {
        case .frontpage:
            fetchFrontpageItemsIfNeeded()
        case .popular:
            fetchPopularItemsIfNeeded()
        case .watched:
            fetchWatchedItemsIfNeeded()
        case .favorites:
            fetchFavoritesItemsIfNeeded()
        case .downloaded:
            print(type)
        case .search:
            print(type)
        case .history:
            print(type)
        }
    }
    func onFavoritesIndexChange(_ : Int) {
        fetchFavoritesItemsIfNeeded()
    }
    func onFavMenuSelect(_ index: Int) {
        store.dispatch(.toggleFavoriteIndex(index: index))
    }
    
    func fetchUserInfo() {
        if let uid = settings.user?.apiuid, !uid.isEmpty {
            store.dispatch(.fetchUserInfo(uid: uid))
        }
    }
    func fetchFavoriteNames() {
        store.dispatch(.fetchFavoriteNames)
    }
    func fetchSearchItems() {
        store.dispatch(.fetchSearchItems(keyword: homeInfo.searchKeyword))
    }
    func fetchFrontpageItems() {
        store.dispatch(.fetchFrontpageItems)
    }
    func fetchPopularItems() {
        store.dispatch(.fetchPopularItems)
    }
    func fetchWatchedItems() {
        store.dispatch(.fetchWatchedItems)
    }
    func fetchFavoritesItems() {
        store.dispatch(.fetchFavoritesItems(index: environment.favoritesIndex))
    }
    
    func fetchMoreSearchItems() {
        store.dispatch(.fetchMoreSearchItems(keyword: homeInfo.searchKeyword))
    }
    func fetchMoreFrontpageItems() {
        store.dispatch(.fetchMoreFrontpageItems)
    }
    func fetchMoreWatchedItems() {
        store.dispatch(.fetchMoreWatchedItems)
    }
    func fetchMoreFavoritesItems() {
        store.dispatch(.fetchMoreFavoritesItems(index: environment.favoritesIndex))
    }
    
    func fetchFrontpageItemsIfNeeded() {
        if homeInfo.frontpageItems?.isEmpty != false {
            fetchFrontpageItems()
        }
    }
    func fetchPopularItemsIfNeeded() {
        if homeInfo.popularItems?.isEmpty != false {
            fetchPopularItems()
        }
    }
    func fetchWatchedItemsIfNeeded() {
        if homeInfo.watchedItems?.isEmpty != false {
            fetchWatchedItems()
        }
    }
    func fetchFavoritesItemsIfNeeded() {
        if homeInfo.favoritesItems[environment.favoritesIndex]?.isEmpty != false {
            fetchFavoritesItems()
        }
    }
}

// MARK: 汎用リスト
private struct GenericList: View {
    @EnvironmentObject var store: Store
    
    var homeInfo: AppState.HomeInfo {
        store.appState.homeInfo
    }
    var homeInfoBinding: Binding<AppState.HomeInfo> {
        $store.appState.homeInfo
    }
    var environment: AppState.Environment {
        store.appState.environment
    }
    
    let items: [Manga]?
    let loadingFlag: Bool
    let notFoundFlag: Bool
    let loadFailedFlag: Bool
    let moreLoadingFlag: Bool
    let moreLoadFailedFlag: Bool
    let fetchAction: (()->())?
    let loadMoreAction: (()->())?
    
    init(
        items: [Manga]?,
        loadingFlag: Bool,
        notFoundFlag: Bool,
        loadFailedFlag: Bool,
        moreLoadingFlag: Bool,
        moreLoadFailedFlag: Bool,
        fetchAction: (()->())? = nil,
        loadMoreAction: (()->())? = nil
    ) {
        self.items = items
        self.loadingFlag = loadingFlag
        self.notFoundFlag = notFoundFlag
        self.loadFailedFlag = loadFailedFlag
        self.moreLoadingFlag = moreLoadingFlag
        self.moreLoadFailedFlag = moreLoadFailedFlag
        self.fetchAction = fetchAction
        self.loadMoreAction = loadMoreAction
        
        UIScrollView.appearance().keyboardDismissMode = .onDrag
    }
    
    var body: some View {
        KRefreshScrollView(
            progressTint: .gray,
            arrowTint: .primary,
            onUpdate: onUpdate
        ) {
            if exx {
                SearchBar(
                    keyword: homeInfoBinding.searchKeyword,
                    commitAction: searchBarCommit,
                    filterAction: searchBarFilter
                )
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            if !didLogin && exx {
                NotLoginView(loginAction: toggleSetting)
                    .padding(.top, 30)
            } else if loadingFlag {
                LoadingView()
                    .padding(.top, 30)
            } else if loadFailedFlag {
                NetworkErrorView(retryAction: fetchAction)
                    .padding(.top, 30)
            } else if notFoundFlag {
                NotFoundView(retryAction: fetchAction)
                    .padding(.top, 30)
            } else {
                ForEach(items ?? []) { item in
                    NavigationLink(destination: DetailView(id: item.id, depth: 0)) {
                        MangaSummaryRow(manga: item)
                            .onAppear {
                                onRowAppear(item)
                            }
                    }
                }
                .padding(.horizontal)
                .transition(
                    AnyTransition
                        .opacity
                        .animation(.default)
                )
                if moreLoadingFlag {
                    LoadingView(isCompact: true)
                        .padding()
                } else if moreLoadFailedFlag {
                    NetworkErrorView(
                        isCompact: true,
                        retryAction: loadMoreAction
                    )
                    .padding()
                }
            }
        }
    }
    
    func onUpdate() {
        if let action = fetchAction {
            action()
        }
    }
    func onRowAppear(_ item: Manga) {
        if let action = loadMoreAction,
           item == items?.last
        {
            action()
        }
    }
    
    func searchBarCommit() {
        if environment.homeListType != .search {
            store.dispatch(.toggleHomeListType(type: .search))
        }
        fetchSearchItems()
    }
    func searchBarFilter() {
        toggleFilter()
    }
    
    func fetchSearchItems() {
        store.dispatch(.fetchSearchItems(keyword: homeInfo.searchKeyword))
    }
    
    func toggleSetting() {
        store.dispatch(.toggleHomeViewSheetState(state: .setting))
    }
    func toggleFilter() {
        store.dispatch(.toggleHomeViewSheetState(state: .filter))
    }
}

// MARK: 検索バー
private struct SearchBar: View {
    @Binding var keyword: String
    var commitAction: () -> ()
    var filterAction: () -> ()
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("検索", text: $keyword, onCommit: commitAction)
                .disableAutocorrection(true)
                .autocapitalization(.none)
            HStack {
                Group {
                    if !keyword.isEmpty {
                        Button(action: onClearButtonTap) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Button(action: filterAction) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.gray)
                            .padding(.vertical, 13)
                            .padding(.trailing, 10)
                    }
                }
            }
        }
        .padding(.leading, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    func onClearButtonTap() {
        keyword = ""
    }
}

// MARK: 定義
enum HomeListType: String, Identifiable, CaseIterable {
    var id: Int { hashValue }
    
    case search = "検索"
    case frontpage = "ホーム"
    case popular = "人気"
    case watched = "タグの購読"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード"
    case history = "閲覧履歴"
    
    var symbolName: String {
        switch self {
        case .search:
            return "magnifyingglass.circle"
        case .frontpage:
            return "house"
        case .popular:
            return "flame"
        case .watched:
            return "tag.circle"
        case .favorites:
            return "heart.circle"
        case .downloaded:
            return "arrow.down.circle"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}

enum HomeViewSheetState: Identifiable {
    var id: Int { hashValue }
    
    case setting
    case filter
}
