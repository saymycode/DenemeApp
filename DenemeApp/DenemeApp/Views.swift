// MARK: - Views
// Root views and screens

import SwiftUI
import MapKit
import CoreLocation
import Combine
import Foundation

struct RootView: View {
    @StateObject private var repository = AppRepository()
    @StateObject private var addressesVM = AddressesViewModel()
    @StateObject private var onboardingVM = OnboardingViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView(repository: repository, addressesVM: addressesVM)
            } else {
                OnboardingPagerView(viewModel: onboardingVM) {
                    hasCompletedOnboarding = true
                }
            }
        }
        .task {
            await repository.loadInitialData()
        }
    }
}

// MARK: Onboarding
struct OnboardingPagerView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var onFinish: () -> Void

    var body: some View {
        VStack {
            TabView(selection: $viewModel.step) {
                OnboardingWelcome().tag(0)
                OnboardingPermissionStep(title: "Konum izni", subtitle: "Mahallene en yakın kesintileri göstermek için konumuna ihtiyacımız var.", buttonTitle: "Konum izni ver", systemImage: "location.fill") {
                    viewModel.requestLocationPermission()
                }
                .tag(1)

                OnboardingPermissionStep(title: "Bildirim izni", subtitle: "Yaklaşan kesintiler için erken uyarı göndereceğiz.", buttonTitle: "Bildirim izni ver", systemImage: "bell.badge.fill") {
                    viewModel.requestNotificationPermission()
                }
                .tag(2)

                ProviderSelectionStep(selected: viewModel.selectedTypes, toggleAction: viewModel.toggle(type:)).tag(3)

                OnboardingFinishStep(onFinish: {
                    viewModel.complete()
                    onFinish()
                }).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                Button("Geri") {
                    withAnimation { viewModel.step = max(viewModel.step - 1, 0) }
                }
                .disabled(viewModel.step == 0)

                Spacer()

                Button(viewModel.step == 4 ? "Başla" : "İleri") {
                    withAnimation {
                        if viewModel.step < 4 { viewModel.step += 1 } else { viewModel.complete(); onFinish() }
                    }
                }
            }
            .padding()
        }
        .background(LinearGradient(colors: [.white, AppColors.secondaryBackground], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

struct OnboardingWelcome: View {
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Spacer()
            Image(systemName: "bolt.fill")
                .font(.system(size: 80))
                .foregroundStyle(AppColors.primary)
            Text("Mahallendeki kesintileri anında öğren.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Elektrik, su, doğalgaz ve internet için tek uygulama.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}

struct OnboardingPermissionStep: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundStyle(AppColors.accent)
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(buttonTitle, action: action)
                .buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding()
    }
}

struct ProviderSelectionStep: View {
    var selected: Set<ProviderType>
    var toggleAction: (ProviderType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("Hangi hizmetler?" ).font(.title.bold())
            Text("İlgilendiğin sağlayıcı tiplerini seç.").foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.m) {
                ForEach(ProviderType.allCases) { type in
                    Button {
                        toggleAction(type)
                    } label: {
                        HStack {
                            Image(systemName: type.symbolName)
                            Text(type.displayName)
                            Spacer()
                            if selected.contains(type) { Image(systemName: "checkmark.circle.fill") }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(selected.contains(type) ? type.tint.opacity(0.15) : AppColors.secondaryBackground)
                        .foregroundStyle(selected.contains(type) ? type.tint : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct OnboardingFinishStep: View {
    var onFinish: () -> Void
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Spacer()
            Image(systemName: "paperplane.fill").font(.system(size: 60)).foregroundStyle(AppColors.primary)
            Text("Hazırsın!").font(.title.bold())
            Text("Kesinti Radar, mahallendeki planlı ve beklenmedik kesintileri takip edecek.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Başla", action: onFinish).buttonStyle(PrimaryButtonStyle())
            Spacer()
        }
        .padding()
    }
}

// MARK: Main Tab View
struct MainTabView: View {
    @ObservedObject var repository: AppRepository
    @ObservedObject var addressesVM: AddressesViewModel

    var body: some View {
        TabView {
            HomeView(repository: repository, addressesVM: addressesVM)
                .tabItem { Label("Ana ekran", systemImage: "house.fill") }
            AddressesView(viewModel: addressesVM)
                .tabItem { Label("Adreslerim", systemImage: "mappin.and.ellipse") }
            StatsView(repository: repository)
                .tabItem { Label("İstatistikler", systemImage: "chart.bar.xaxis") }
            SettingsView(viewModel: SettingsViewModel())
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
    }
}

// MARK: Home
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject var addressesVM: AddressesViewModel
    @State private var showMap = false

    init(repository: AppRepository, addressesVM: AddressesViewModel) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(repository: repository))
        self.addressesVM = addressesVM
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    header
                    filters
                    addressCarousel
                    mapPreview
                    outageList
                }
                .padding()
            }
            .navigationTitle("Kesinti Radar")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(action: { Task { await viewModel.refresh() } }, label: { Image(systemName: "arrow.clockwise") }) } }
            .refreshable { await viewModel.refresh() }
            .sheet(isPresented: $showMap) { OutageMapView(outages: viewModel.filteredOutages) }
            .onAppear { viewModel.load(addresses: addressesVM.addresses) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Merhaba 👋")
                .font(.title2.bold())
            Text("Bugün mahallende neler oluyor?")
                .foregroundStyle(.secondary)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button(action: { withAnimation { viewModel.selectedProviderType = nil; viewModel.applyFilters() } }) {
                        TagChipView(text: "Hepsi", color: viewModel.selectedProviderType == nil ? AppColors.primary : .gray)
                    }
                    ForEach(ProviderType.allCases) { type in
                        Button(action: { withAnimation { viewModel.selectedProviderType = type; viewModel.applyFilters() } }) {
                            TagChipView(text: type.displayName, color: type.tint)
                        }
                    }
                }
            }
            HStack {
                ForEach(OutageStatus.allCases) { status in
                    Button(action: { withAnimation { viewModel.statusFilter = status; viewModel.applyFilters() } }) {
                        TagChipView(text: status.label, color: status.chipColor)
                    }
                }
                Button(action: { withAnimation { viewModel.statusFilter = nil; viewModel.applyFilters() } }) {
                    TagChipView(text: "Tümü", color: AppColors.accent)
                }
            }
        }
    }

    private var addressCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.m) {
                ForEach(addressesVM.addresses) { address in
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text(address.label).font(.headline)
                        Text(address.fullText).foregroundStyle(.secondary).font(.subheadline)
                        if address.isPrimary { TagChipView(text: "Birincil", color: AppColors.good) }
                    }
                    .padding()
                    .frame(width: 220, alignment: .leading)
                    .background(AppColors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.vertical, AppSpacing.s)
        }
    }

    private var mapPreview: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Harita önizleme").font(.headline)
                Spacer()
                Button("Aç") { showMap = true }
            }
            Map {
                ForEach(viewModel.filteredOutages) { outage in
                    Marker(outage.title, coordinate: CLLocationCoordinate2D(latitude: outage.latitude, longitude: outage.longitude))
                        .tint(outage.type.tint)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var outageList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Kesintiler")
                .font(.headline)
            if viewModel.isLoading {
                ForEach(0..<3) { _ in skeletonCard }
            } else if let error = viewModel.error {
                VStack(spacing: AppSpacing.s) {
                    Text(error.localizedDescription).foregroundStyle(.secondary)
                    Button("Tekrar dene") { Task { await viewModel.refresh() } }
                }
            } else if viewModel.filteredOutages.isEmpty {
                VStack(spacing: AppSpacing.s) {
                    Image(systemName: "checkmark.shield")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.good)
                    Text("Bugün için planlı bir kesinti görünmüyor. Harika!")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(viewModel.filteredOutages) { outage in
                    NavigationLink(destination: OutageDetailView(outage: outage, repository: viewModel.repository)) {
                        OutageCard(outage: outage)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var skeletonCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(AppColors.secondaryBackground)
            .frame(height: 120)
            .redacted(reason: .placeholder)
    }
}

struct OutageCard: View {
    let outage: Outage
    var body: some View {
        AppCard {
            HStack(alignment: .top, spacing: AppSpacing.m) {
                Image(systemName: outage.type.symbolName)
                    .font(.title2)
                    .foregroundStyle(outage.type.tint)
                    .padding(AppSpacing.s)
                    .background(outage.type.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack {
                        Text(outage.title).font(.headline)
                        Spacer()
                        TagChipView(text: outage.status.label, color: outage.status.chipColor)
                    }
                    Text(outage.provider.name).foregroundStyle(.secondary).font(.subheadline)
                    Text("Başlangıç: \(outage.startDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack {
                        Label("\(outage.userReportedCount) kişi bildirildi", systemImage: "person.2.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if outage.isUpcoming { TagChipView(text: "Yakında", color: AppColors.warning) }
                        if outage.isActiveNow { TagChipView(text: "Devam ediyor", color: AppColors.bad) }
                    }
                }
            }
        }
    }
}

struct OutageMapView: View {
    let outages: [Outage]
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Map {
                ForEach(outages) { outage in
                    Marker(outage.title, coordinate: CLLocationCoordinate2D(latitude: outage.latitude, longitude: outage.longitude))
                        .tint(outage.type.tint)
                }
            }
            .ignoresSafeArea()
            .navigationTitle("Harita")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Kapat") { dismiss() } } }
        }
    }
}

// MARK: Outage Detail
struct OutageDetailView: View {
    @StateObject private var viewModel: OutageDetailViewModel
    @State private var showReportSheet = false
    @State private var reportComment: String = ""
    @State private var isPowerBack: Bool = false

    init(outage: Outage, repository: AppRepository) {
        _viewModel = StateObject(wrappedValue: OutageDetailViewModel(outage: outage, repository: repository))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.l) {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        HStack {
                            Image(systemName: viewModel.outage.type.symbolName).foregroundStyle(viewModel.outage.type.tint)
                            Text(viewModel.outage.title).font(.title2.bold())
                            Spacer()
                            TagChipView(text: viewModel.outage.status.label, color: viewModel.outage.status.chipColor)
                        }
                        Text(viewModel.outage.provider.name).foregroundStyle(.secondary)
                        Text(dateInfo)
                            .font(.subheadline)
                        TagChipView(text: statusDescription, color: viewModel.outage.isActiveNow ? AppColors.bad : AppColors.warning)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("Etkilenen bölgeler").font(.headline)
                        ForEach(viewModel.outage.affectedAreas, id: \.self) { area in
                            Label(area, systemImage: "mappin")
                        }
                    }
                }

                Map(initialPosition: .camera(.init(centerCoordinate: CLLocationCoordinate2D(latitude: viewModel.outage.latitude, longitude: viewModel.outage.longitude), distance: 2000))) {
                    Marker(viewModel.outage.title, coordinate: CLLocationCoordinate2D(latitude: viewModel.outage.latitude, longitude: viewModel.outage.longitude))
                        .tint(viewModel.outage.type.tint)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    Text("Bu kesinti hakkında").font(.headline)
                    Text(viewModel.outage.description)
                    if let url = viewModel.outage.sourceUrl { Link("Kaynak", destination: url) }
                }
                .cardBackground()

                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack {
                        Text("Kullanıcı geri bildirimleri").font(.headline)
                        Spacer()
                        Button("Bildir") { showReportSheet = true }
                    }
                    ForEach(viewModel.reports) { report in
                        VStack(alignment: .leading) {
                            Text(report.isPowerBack ? "Geri geldi" : "Kesildi")
                                .font(.subheadline.bold())
                            if let comment = report.comment { Text(comment).foregroundStyle(.secondary) }
                            Text(report.timestamp, style: .time).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(AppColors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .cardBackground()
            }
            .padding()
        }
        .navigationTitle("Detay")
        .sheet(isPresented: $showReportSheet) {
            NavigationStack {
                Form {
                    Section("Durum") {
                        Toggle("Geri geldi", isOn: $isPowerBack)
                    }
                    Section("Yorum") {
                        TextField("İstersen yorum bırak", text: $reportComment, axis: .vertical)
                    }
                }
                .navigationTitle("Bildirim gönder")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Kapat") { showReportSheet = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Gönder") {
                        viewModel.addReport(isPowerBack: isPowerBack, comment: reportComment.isEmpty ? nil : reportComment)
                        showReportSheet = false
                    } }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private var dateInfo: String {
        let start = viewModel.outage.startDate.formatted(date: .abbreviated, time: .shortened)
        if let end = viewModel.outage.estimatedEndDate?.formatted(date: .abbreviated, time: .shortened) {
            return "\(start) - \(end)"
        }
        return start
    }

    private var statusDescription: String {
        if viewModel.outage.isUpcoming { return "Yaklaşan kesinti" }
        if viewModel.outage.isActiveNow { return "Şu an devam ediyor" }
        return "Geçmiş"
    }
}

// MARK: Addresses
struct AddressesView: View {
    @ObservedObject var viewModel: AddressesViewModel
    @State private var showingSheet = false
    @State private var label: String = ""
    @State private var fullText: String = ""
    @State private var coordinate = CLLocationCoordinate2D(latitude: 38.4237, longitude: 27.1428)

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.addresses) { address in
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        HStack {
                            Text(address.label).font(.headline)
                            if address.isPrimary { TagChipView(text: "Birincil", color: AppColors.good) }
                        }
                        Text(address.fullText).foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Sil", role: .destructive) { delete(address) }
                        Button("Birincil") { viewModel.setPrimary(address) }
                    }
                }
                .onDelete(perform: viewModel.delete)
                .onMove(perform: viewModel.move)
            }
            .navigationTitle("Adreslerim")
            .toolbar { EditButton() }
            .safeAreaInset(edge: .bottom) {
                Button(action: { showingSheet = true }) {
                    Label("Adres ekle", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .sheet(isPresented: $showingSheet) { addSheet }
        }
    }

    private func delete(_ address: Address) {
        if let index = viewModel.addresses.firstIndex(where: { $0.id == address.id }) {
            viewModel.addresses.remove(at: index)
            viewModel.persist()
        }
    }

    private var addSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.m) {
                Form {
                    Section("Etiket") { TextField("Ev / İş", text: $label) }
                    Section("Adres") { TextField("Adres açıklaması", text: $fullText) }
                    Section("Konum") {
                        Map(initialPosition: .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))) {
                            Marker("Yeni adres", coordinate: coordinate)
                        }
                        .frame(height: 200)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
            }
            .navigationTitle("Yeni adres")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { saveAddress() } }
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { showingSheet = false } }
            }
        }
    }

    private func saveAddress() {
        guard !label.isEmpty, !fullText.isEmpty else { return }
        viewModel.addAddress(label: label, fullText: fullText, coordinate: coordinate)
        label = ""; fullText = ""
        showingSheet = false
    }
}

// MARK: Stats
struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @ObservedObject var repository: AppRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Picker("Zaman", selection: $viewModel.range) {
                    Text("7 gün").tag(7)
                    Text("30 gün").tag(30)
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: { viewModel.selectedType = nil }) { TagChipView(text: "Tümü", color: AppColors.primary) }
                        ForEach(ProviderType.allCases) { type in
                            Button(action: { viewModel.selectedType = type }) { TagChipView(text: type.displayName, color: type.tint) }
                        }
                    }
                }

                HStack(spacing: AppSpacing.m) {
                    statCard(title: "Planlı", value: viewModel.planCount, color: AppColors.warning)
                    statCard(title: "Plansız", value: viewModel.unplannedCount, color: AppColors.bad)
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("Günlük dağılım")
                        GeometryReader { geometry in
                            let height = geometry.size.height
                            let counts = dailyCounts()
                            HStack(alignment: .bottom, spacing: 6) {
                                ForEach(counts.indices, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(AppColors.accent)
                                        .frame(width: 12, height: CGFloat(counts[index]) / CGFloat((counts.max() ?? 1)) * height)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                        .frame(height: 120)
                    }
                }

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        Text("En yoğun gün")
                        Text(viewModel.busiestDay).font(.title3.bold())
                        Text("En sakin gün")
                        Text(viewModel.calmDay).font(.title3.bold())
                    }
                }
            }
            .padding()
            .onAppear {
                Task {
                    let result = await repository.getOutagesForCurrentLocation(latitude: 38.4, longitude: 27.1)
                    if case let .success(data) = result { viewModel.load(outages: data) }
                }
            }
        }
        .navigationTitle("İstatistikler")
    }

    private func statCard(title: String, value: Int, color: Color) -> some View {
        AppCard {
            VStack(alignment: .leading) {
                Text(title).foregroundStyle(.secondary)
                Text("\(value)").font(.largeTitle.bold()).foregroundStyle(color)
            }
        }
    }

    private func dailyCounts() -> [Int] {
        let grouped = Dictionary(grouping: viewModel.filtered) { Calendar.current.component(.day, from: $0.startDate) }
        return grouped.keys.sorted().map { grouped[$0]?.count ?? 0 }
    }
}

// MARK: Settings
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Bildirimler") {
                    Toggle("Elektrik", isOn: $viewModel.notificationElectricity)
                    Toggle("Su", isOn: $viewModel.notificationWater)
                    Toggle("Doğalgaz", isOn: $viewModel.notificationGas)
                    Toggle("İnternet", isOn: $viewModel.notificationInternet)
                }

                Section("Görüntüleme") {
                    Toggle("Geçmiş kesintileri göster", isOn: $viewModel.showPast)
                }

                Section("Veri & Gizlilik") {
                    Button("Önbelleği temizle") { viewModel.clearCache() }
                    Text("Konum yalnızca yakın çevrendeki kesintileri göstermek için kullanılır.")
                }

                Section("Debug") {
                    Button("Mock modu değiştir") { NotificationManager.shared.cancelAll() }
                }

                Section { Text("Sürüm 1.0") }
            }
            .navigationTitle("Ayarlar")
        }
    }
}

// MARK: ContentView placeholder for previews
struct ContentView: View {
    var body: some View {
        RootView()
    }
}

#Preview("Ana ekran") {
    RootView()
}
