import SwiftUI
import AVKit
import EkitapligimCore

@MainActor
struct AudioMiniPlayerView: View {
    @ObservedObject var controller: AudioPlaybackController
    var onExpand: () -> Void
    var body: some View {
        if controller.visible && !controller.expanded {
            VStack(spacing: 0) {
                ProgressView(value: min(controller.position, max(controller.duration, 1)), total: max(controller.duration, 1))
                    .tint(AudioStyle.gold).accessibilityHidden(true)
                HStack(spacing: 10) {
                    Button(action: onExpand) {
                        HStack(spacing: 12) {
                            if let book = controller.book { AudioCoverView(book: book, width: 33) }
                            else { Image(systemName: "headphones").font(.title2).frame(width: 33) }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(controller.book?.title ?? AudioL10n.text("title")).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(controller.book?.author ?? AudioL10n.text("nowListening")).font(.caption).foregroundStyle(AudioStyle.muted).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(AudioL10n.text("expand"))
                    if controller.loading { ProgressView().frame(width: 44, height: 44).tint(AudioStyle.teal) }
                    else {
                        Button { controller.toggle() } label: { Image(systemName: controller.playing ? "pause.fill" : "play.fill").font(.title3).frame(width: 44, height: 44) }
                            .accessibilityLabel(AudioL10n.text(controller.playing ? "pause" : "play")).buttonStyle(.plain)
                    }
                    Button { controller.close() } label: { Image(systemName: "xmark").font(.body.weight(.semibold)).frame(width: 44, height: 44) }
                        .buttonStyle(.plain).accessibilityLabel(AudioL10n.text("stopClose")).accessibilityIdentifier("audio.mini.close")
                }.padding(.horizontal, 12).padding(.vertical, 9)
            }.foregroundStyle(AudioStyle.ink).background(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(AudioStyle.line).frame(height: 1) }
                .accessibilityIdentifier("audio.mini")
        }
    }
}

private struct AudioAnnotationAnchor: Identifiable {
    let id = UUID()
    let bookID: Int
    let chapterID: Int
    let position: Double
    let kind: AudioAnnotationKind
}

@MainActor
struct AudioPlayerView: View {
    @ObservedObject var controller: AudioPlaybackController
    var onBook: (Int) -> Void
    var onPremium: () -> Void
    var onLogin: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var annotation: AudioAnnotationAnchor?
    @State private var settingsPresented = false
    @State private var premiumPresented = false
    @State private var seeking = false
    @State private var seekPosition: Double = 0
    @State private var editorText = ""
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width >= 820 {
                    HStack(alignment: .top, spacing: 18) {
                        playerColumn.frame(maxWidth: .infinity)
                        chaptersPanel.frame(maxWidth: .infinity)
                    }.padding(20)
                } else {
                    VStack(spacing: 20) { playerColumn; chaptersPanel }.padding(16)
                }
            }.background(AudioStyle.cream)
        }.navigationTitle(AudioL10n.text("nowListening")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel(AudioL10n.text("minimize")) }
                ToolbarItem(placement: .topBarTrailing) { Button { controller.close(); dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel(AudioL10n.text("stopClose")) }
            }
            .tint(AudioStyle.ink)
            .sheet(isPresented: $settingsPresented) { settings }
            .sheet(isPresented: $premiumPresented) { AudioPremiumAccessView(onPremium: onPremium) }
            .sheet(item: $annotation) { anchor in annotationEditor(anchor) }
            .task { handlePendingNote() }
            .onAppear { controller.expanded = true }
            .onDisappear { controller.expanded = false }
            .onChange(of: controller.loading) { _, _ in handlePendingNote() }
            .onChange(of: controller.noteRequested) { _, _ in handlePendingNote() }
            .onChange(of: controller.book?.id) { _, _ in annotation = nil; editorText = ""; tab = 0; handlePendingNote() }
            .accessibilityIdentifier("audio.player")
    }
    private var playerColumn: some View {
        VStack(spacing: 20) {
            artwork
            if let book = controller.book {
                Text(book.title).font(.system(.largeTitle, design: .serif, weight: .bold)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Text(book.author).font(.title3).foregroundStyle(AudioStyle.muted)
                if !book.description.isEmpty { Text(book.description).font(.caption).foregroundStyle(AudioStyle.muted).multilineTextAlignment(.center).lineLimit(3) }
            }
            if let error = controller.error {
                VStack(spacing: 10) {
                    AudioErrorView(message: error) { controller.retry() }
                    if controller.accessError == .premiumRequired { AudioActionButton(title: AudioL10n.text("viewPremium"), icon: "crown.fill", prominent: true) { premiumPresented = true } }
                    if controller.accessError == .authenticationRequired || controller.accessError == .accountChanged { AudioActionButton(title: AudioL10n.text("signIn"), icon: "person.crop.circle", prominent: true, action: onLogin) }
                }
            }
            progress
            controls
            ViewThatFits(in: .horizontal) {
                HStack { settingsButton; bookmarkButton; noteButton }
                VStack { settingsButton; HStack { bookmarkButton; noteButton } }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(AudioL10n.text("volume")).font(.caption)
                HStack {
                Image(systemName: "speaker.fill")
                Slider(value: Binding(get: { Double(controller.volume) }, set: { controller.setVolume(Float($0)) }), in: 0...1)
                    .tint(AudioStyle.gold).accessibilityLabel(AudioL10n.text("volume"))
                Image(systemName: "speaker.wave.3.fill")
                AudioRoutePicker().frame(width: 44, height: 44).accessibilityLabel(AudioL10n.text("settings"))
                }
            }.foregroundStyle(AudioStyle.muted).padding(.horizontal, 8)
        }.foregroundStyle(AudioStyle.ink).padding(18)
            .background {
                GeometryReader { geometry in
                    AudioArtwork(name: controller.book?.title.localizedCaseInsensitiveContains("Küçük Prens") == true ? "audio_moon_landscape" : "audio_story_landscape")
                        .frame(width: geometry.size.width, height: min(540, geometry.size.height)).clipped()
                    LinearGradient(colors: [AudioStyle.cream.opacity(0.15), AudioStyle.cream.opacity(0.92), AudioStyle.cream], startPoint: .top, endPoint: .bottom)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 26))
    }
    private var artwork: some View {
        VStack(spacing: 15) {
            Label(AudioL10n.text("nowListening"), systemImage: "headphones").font(.caption.weight(.semibold)).tracking(1)
                .padding(.horizontal, 16).padding(.vertical, 10).foregroundStyle(AudioStyle.cream).background(AudioStyle.ink.opacity(0.85)).clipShape(Capsule())
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { cover; VStack(spacing: 12) { artworkActions } }
                VStack(spacing: 16) { cover; HStack(spacing: 12) { artworkActions } }
            }.padding(.vertical, 8)
        }
    }
    @ViewBuilder private var cover: some View {
        if let book = controller.book { AudioCoverView(book: book, width: 166) }
        else { ProgressView().frame(width: 166, height: 240).tint(AudioStyle.ink) }
    }
    @ViewBuilder private var artworkActions: some View {
        Button { Task { await controller.toggleFavorite() } } label: { Image(systemName: controller.favorite ? "heart.fill" : "heart").font(.title3).frame(width: 44, height: 44).background(AudioStyle.ink.opacity(0.7)).clipShape(Circle()) }
            .foregroundStyle(AudioStyle.cream).accessibilityLabel(AudioL10n.text(controller.favorite ? "favorited" : "favorite"))
        if let url = URL(string: controller.book?.url ?? ""), url.scheme == "https", url.user == nil, url.password == nil {
            ShareLink(item: url) { Image(systemName: "square.and.arrow.up").font(.title3).frame(width: 44, height: 44).background(AudioStyle.ink.opacity(0.7)).clipShape(Circle()) }
                .foregroundStyle(AudioStyle.cream).accessibilityLabel(AudioL10n.text("share"))
        }
    }
    private var progress: some View {
        VStack(spacing: 8) {
            AudioWaveform(progress: controller.duration > 0 ? controller.position / controller.duration : 0).frame(height: 32).accessibilityHidden(true)
            Slider(value: Binding(get: { seeking ? seekPosition : min(controller.position, max(1, controller.duration)) }, set: { seekPosition = $0 }), in: 0...max(1, controller.duration), onEditingChanged: { editing in
                seeking = editing
                if editing { seekPosition = controller.position } else { controller.seek(to: seekPosition) }
            }).tint(AudioStyle.gold).disabled(controller.loading || controller.chapter == nil).accessibilityLabel(AudioL10n.text("progress"))
                .accessibilityValue(AudioPolicy.time(controller.position))
            HStack(alignment: .top) {
                Text(AudioPolicy.time(seeking ? seekPosition : controller.position))
                Spacer(minLength: 10)
                Text(controller.chapter?.title ?? "").fontWeight(.semibold).multilineTextAlignment(.center)
                Spacer(minLength: 10)
                Text("−" + AudioPolicy.time(max(0, controller.duration - controller.position)))
            }.font(.caption2).monospacedDigit()
        }
    }
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 5) { previousControl; rewindControl; playControl; forwardControl; nextControl }
            VStack(spacing: 8) { HStack(spacing: 12) { rewindControl; playControl; forwardControl }; HStack(spacing: 30) { previousControl; nextControl } }
        }.frame(maxWidth: .infinity).foregroundStyle(AudioStyle.ink)
    }
    private var previousControl: some View { control("backward.end.fill", key: "previous") { if controller.canPrevious { controller.selectChapter(controller.chapterIndex - 1) } }.disabled(!controller.canPrevious) }
    private var nextControl: some View { control("forward.end.fill", key: "next") { if controller.canNext { controller.selectChapter(controller.chapterIndex + 1) } }.disabled(!controller.canNext) }
    private var rewindControl: some View { control("gobackward.15", key: "rewind") { controller.skip(-15) } }
    private var forwardControl: some View { control("goforward.15", key: "forward") { controller.skip(15) } }
    private var playControl: some View {
        Button { controller.toggle() } label: {
            ZStack {
                Circle().fill(AudioStyle.gradient).overlay(Circle().stroke(AudioStyle.gold, lineWidth: 2))
                if controller.loading { ProgressView().tint(.white) }
                else { Image(systemName: controller.playing ? "pause.fill" : "play.fill").font(.title).foregroundStyle(.white) }
            }.frame(width: 76, height: 76).shadow(color: AudioStyle.gold.opacity(0.22), radius: 8, y: 3)
        }.buttonStyle(.plain).accessibilityLabel(AudioL10n.text(controller.playing ? "pause" : "play"))
    }
    private func control(_ icon: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.title2.weight(.medium)).frame(minWidth: 44, minHeight: 48).contentShape(Rectangle()) }
            .buttonStyle(.plain).accessibilityLabel(AudioL10n.text(key))
    }
    private var settingsButton: some View { AudioActionButton(title: AudioL10n.text("settings"), icon: "gearshape") { settingsPresented = true } }
    private var bookmarkButton: some View { AudioActionButton(title: AudioL10n.text("bookmark"), icon: "bookmark") { Task { await controller.addBookmark() } }.disabled(controller.savingBookmark || controller.chapter == nil) }
    private var noteButton: some View { AudioActionButton(title: AudioL10n.text("addNote"), icon: "square.and.pencil") { openEditor(.note) }.disabled(controller.chapter == nil) }
    private var chaptersPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(["chapters", "notes", "quotes"].enumerated()), id: \.offset) { index, key in
                        Button { tab = index } label: {
                            Text(AudioL10n.text(key)).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 46)
                                .foregroundStyle(tab == index ? Color.white : AudioStyle.ink).background(tab == index ? AudioStyle.ink : Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).accessibilityAddTraits(tab == index ? .isSelected : [])
                    }
                }
            }
            if tab == 0 {
                Text(AudioL10n.text("chapters")).font(.system(.title2, design: .serif, weight: .bold))
                ForEach(Array((controller.manifest?.chapters ?? []).enumerated()), id: \.element.id) { index, chapter in
                    Button { controller.selectChapter(index) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: index == controller.chapterIndex ? "waveform" : "play.circle.fill").foregroundStyle(AudioStyle.teal)
                            Text(chapter.title).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
                            Text(AudioPolicy.time(chapter.duration)).font(.caption).foregroundStyle(AudioStyle.muted)
                        }.padding(14).frame(minHeight: 52).background(index == controller.chapterIndex ? AudioStyle.teal.opacity(0.1) : .white.opacity(0.6)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).accessibilityAddTraits(index == controller.chapterIndex ? .isSelected : [])
                }
            } else {
                AudioActionButton(title: AudioL10n.text(tab == 2 ? "addQuote" : "addNote"), icon: tab == 2 ? "quote.opening" : "square.and.pencil", prominent: true) { openEditor(tab == 2 ? .quote : .note) }
                if let error = controller.annotationError { Text(error).font(.caption).foregroundStyle(.red) }
                let items = controller.bookmarks.filter { tab == 2 ? $0.kind == .quote : $0.kind != .quote }
                if items.isEmpty { Text(AudioL10n.text(tab == 2 ? "emptyQuotes" : "emptyNotes")).font(.subheadline).foregroundStyle(AudioStyle.muted).padding(.vertical, 16) }
                ForEach(items) { bookmark in
                    VStack(alignment: .leading, spacing: 12) {
                        Button { controller.openBookmark(bookmark) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AudioPolicy.time(bookmark.position)).font(.caption.weight(.semibold)).foregroundStyle(AudioStyle.teal)
                                Text(bookmark.displayText.isEmpty ? AudioL10n.text("bookmarkTitle") : bookmark.displayText).font(.body).multilineTextAlignment(.leading).foregroundStyle(AudioStyle.ink)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        HStack {
                            ShareLink(item: bookmark.displayText) { Label(AudioL10n.text("share"), systemImage: "square.and.arrow.up") }
                            Spacer()
                            Button(role: .destructive) { Task { await controller.deleteBookmark(bookmark) } } label: { Label(AudioL10n.text("delete"), systemImage: "trash") }
                        }.font(.caption).frame(minHeight: 44)
                    }.padding(15).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            if let related = controller.manifest?.recommendations, !related.isEmpty {
                Divider().padding(.vertical, 10)
                AudioShelfView(title: AudioL10n.text("similar"), books: related) { id in dismiss(); onBook(id) }
            }
        }.padding(20).foregroundStyle(AudioStyle.ink).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 25)).overlay(RoundedRectangle(cornerRadius: 25).stroke(AudioStyle.gold.opacity(0.18), lineWidth: 1))
    }
    private var settings: some View {
        NavigationStack {
            Form {
                Section(AudioL10n.text("speed")) {
                    Picker(AudioL10n.text("speed"), selection: Binding(get: { controller.speed }, set: controller.setSpeed)) {
                        ForEach([0.5, 0.75, 1, 1.25, 1.5, 1.75, 2], id: \.self) { value in Text(String(format: "%g×", value)).tag(value) }
                    }
                }
                Section(AudioL10n.text("sleep")) {
                    ForEach([0, 15, 30, 45, 60, 90], id: \.self) { minutes in
                        Button { controller.setSleep(minutes: minutes) } label: {
                            HStack { Text(minutes == 0 ? AudioL10n.text("sleepOff") : AudioL10n.format("minutes", minutes)); Spacer(); if !controller.sleepAtChapterEnd && controller.sleepMinutes == minutes { Image(systemName: "checkmark") } }
                        }
                    }
                    Button { controller.setSleepAtChapterEnd() } label: { HStack { Text(AudioL10n.text("sleepEnd")); Spacer(); if controller.sleepAtChapterEnd { Image(systemName: "checkmark") } } }
                }
            }.navigationTitle(AudioL10n.text("settings")).toolbar { ToolbarItem(placement: .confirmationAction) { Button(AudioL10n.text("done")) { settingsPresented = false } } }
        }.tint(AudioStyle.teal).presentationDragIndicator(.visible)
    }
    private func annotationEditor(_ anchor: AudioAnnotationAnchor) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(AudioL10n.text("annotationHint")).font(.subheadline).foregroundStyle(AudioStyle.muted)
                Text(AudioPolicy.time(anchor.position)).font(.caption.weight(.semibold)).foregroundStyle(AudioStyle.teal)
                TextEditor(text: $editorText).foregroundStyle(AudioStyle.ink).tint(AudioStyle.teal).scrollContentBackground(.hidden)
                    .padding(12).frame(minHeight: 180).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AudioStyle.line, lineWidth: 1))
                    .accessibilityLabel(AudioL10n.text(anchor.kind == .quote ? "quoteText" : "noteText")).accessibilityIdentifier("audio.annotation.text")
                    .onChange(of: editorText) { _, value in if value.count > 230 { editorText = String(value.prefix(230)) } }
                if let error = controller.annotationError { Text(error).font(.caption).foregroundStyle(.red) }
                Spacer()
            }.padding(22).background(AudioStyle.paper).foregroundStyle(AudioStyle.ink)
                .navigationTitle(AudioL10n.text(anchor.kind == .quote ? "addQuote" : "addNote"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(AudioL10n.text("cancel")) { annotation = nil; editorText = "" } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AudioL10n.text("saveAnnotation")) {
                            Task {
                                guard controller.book?.id == anchor.bookID else { return }
                                await controller.addAnnotation(kind: anchor.kind, text: editorText, chapterID: anchor.chapterID, position: anchor.position)
                                if controller.annotationError == nil { annotation = nil; editorText = "" }
                            }
                        }.disabled(editorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.savingBookmark)
                    }
                }
        }.tint(AudioStyle.teal).presentationDragIndicator(.visible)
    }
    private func openEditor(_ kind: AudioAnnotationKind) {
        guard let book = controller.book, let chapter = controller.chapter else { return }
        editorText = ""; annotation = AudioAnnotationAnchor(bookID: book.id, chapterID: chapter.id, position: controller.position, kind: kind)
    }
    private func handlePendingNote() {
        if controller.noteRequested, !controller.loading, controller.chapter != nil { controller.noteRequested = false; openEditor(.note) }
    }
}

@MainActor
private struct AudioWaveform: View {
    let progress: Double
    var body: some View {
        Canvas { context, size in
            let count = max(1, Int(size.width / 5))
            for index in 0..<count {
                let x = CGFloat(index) * size.width / CGFloat(count)
                let height = 5 + CGFloat(abs(sin(Double(index) * 0.47) * cos(Double(index) * 0.16))) * (size.height - 5)
                let rect = CGRect(x: x, y: (size.height - height) / 2, width: 2.6, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1.3), with: .color(Double(index) / Double(count) <= progress ? AudioStyle.gold : AudioStyle.gold.opacity(0.28)))
            }
        }
    }
}
@MainActor
private struct AudioRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.activeTintColor = UIColor(AudioStyle.teal); view.tintColor = UIColor(AudioStyle.ink); return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
