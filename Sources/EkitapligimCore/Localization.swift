import Foundation

public enum L10n {
    public static let bookDetailTitle = localized("book.detail.title", defaultValue: "Kitap Detayı")
    public static let bookDetailLoading = localized("book.detail.loading", defaultValue: "Kitap yükleniyor")
    public static let bookDetailOpenFailed = localized("book.detail.openFailed", defaultValue: "Kitap açılamadı")
    public static let bookDetailMissingDescription = localized("book.detail.missingDescription", defaultValue: "Bu kitap için özet henüz eklenmemiş.")
    public static let bookDetailRead = localized("book.detail.read", defaultValue: "Hemen Oku")
    public static let bookDetailCheckReading = localized("book.detail.checkReading", defaultValue: "Okuma durumunu kontrol et")
    public static let bookDetailOfflineDownload = localized("book.detail.offlineDownload", defaultValue: "İndir")
    public static let bookDetailReportIssue = localized("book.detail.reportIssue", defaultValue: "Sorun bildir")
    public static let bookDetailIssueTitle = localized("book.detail.issueTitle", defaultValue: "Sorun mu var?")
    public static let bookDetailIssueSubtitle = localized("book.detail.issueSubtitle", defaultValue: "Kitap kaydıyla ilgili hızlı bildirim gönderin.")
    public static let bookDetailIssueBrokenLink = localized("book.detail.issueBrokenLink", defaultValue: "Kırık link")
    public static let bookDetailIssueMissingCover = localized("book.detail.issueMissingCover", defaultValue: "Eksik kapak")
    public static let bookDetailIssueCopyright = localized("book.detail.issueCopyright", defaultValue: "Telif")
    public static let bookDetailIssueLoginRequired = localized("book.detail.issueLoginRequired", defaultValue: "Bildirimde bulunmak için giriş yapmalısınız.")
    public static let bookDetailIssueCopyrightLoginRequired = localized("book.detail.issueCopyrightLoginRequired", defaultValue: "Telif bildirimi için giriş yapmalısınız.")
    public static func bookDetailIssueSubmitted(_ label: String) -> String {
        String(format: localized("book.detail.issueSubmitted", defaultValue: "%@ bildiriminiz alındı."), label)
    }
    public static let bookDetailIssueSubmitFailed = localized("book.detail.issueSubmitFailed", defaultValue: "Bildirim gönderilemedi. Lütfen tekrar deneyin.")
    public static let bookDetailLoadFailed = localized("book.detail.loadFailed", defaultValue: "Kitap bilgileri alınamadı.")
    public static let bookDetailSimilarBooks = localized("book.detail.similarBooks", defaultValue: "Benzer Kitaplar")
    public static let bookDetailInvalidId = localized("book.detail.invalidId", defaultValue: "Kitap kimliği geçersiz.")
    public static let bookDetailSecureDownloadMissing = localized("book.detail.secureDownloadMissing", defaultValue: "Güvenli indirme bağlantısı alınamadı.")
    public static let bookDetailLoginRequiredMessage = localized("book.detail.loginRequiredMessage", defaultValue: "Okumak veya indirmek için giriş yapın.")
    public static let bookDetailDownloadReady = localized("book.detail.downloadReady", defaultValue: "Kitap çevrimdışı okuma için indirildi.")
    public static let bookDetailDownloadStarted = localized("book.detail.downloadStarted", defaultValue: "İndirme başlatıldı.")
    public static let bookDetailInfoTitle = localized("book.detail.infoTitle", defaultValue: "Kitap Künyesi")
    public static let bookDetailInfoCategory = localized("book.detail.infoCategory", defaultValue: "Kategori")
    public static let bookDetailInfoLanguage = localized("book.detail.infoLanguage", defaultValue: "Dil")
    public static let bookDetailInfoISBN = localized("book.detail.infoISBN", defaultValue: "ISBN")
    public static let bookDetailInfoYear = localized("book.detail.infoYear", defaultValue: "Yayın Yılı")
    public static let bookDetailInfoPages = localized("book.detail.infoPages", defaultValue: "Sayfa")
    public static let bookDetailInfoFormat = localized("book.detail.infoFormat", defaultValue: "Format")
    public static let bookDetailUnknownFormat = localized("book.detail.unknownFormat", defaultValue: "PDF / EPUB")
    public static let bookDetailSynopsisSectionTitle = localized("book.detail.synopsisSectionTitle", defaultValue: "Özet / Açıklama")
    public static let bookDetailAddToFavorites = localized("book.detail.addToFavorites", defaultValue: "Favorilerime ekle")
    public static func bookDetailDownloadCount(_ count: Int) -> String {
        String(format: localized("book.detail.downloadCount", defaultValue: "%d indirme"), count)
    }
    public static let bookDetailUnspecified = localized("book.detail.unspecified", defaultValue: "Belirtilmemiş")
    public static let bookDetailSynopsisTitle = localized("book.detail.synopsisTitle", defaultValue: "Kitap Özeti")
    public static let bookDetailSynopsisSubtitle = localized("book.detail.synopsisSubtitle", defaultValue: "Açıklama içeriği")
    public static let bookDetailSynopsisReadMore = localized("book.detail.synopsisReadMore", defaultValue: "Devamını oku")
    public static let bookDetailSynopsisShowLess = localized("book.detail.synopsisShowLess", defaultValue: "Daha az göster")
    public static let libraryUpdateFailed = localized("library.updateFailed", defaultValue: "Raf güncellenemedi.")
    public static let bookCommentsTitle = localized("bookComments.title", defaultValue: "Kullanıcı Yorumları")
    public static func bookCommentsTitleCount(_ count: Int) -> String {
        String(format: localized("bookComments.titleCount", defaultValue: "Kullanıcı Yorumları (%d)"), count)
    }
    public static let bookCommentsYourRating = localized("bookComments.yourRating", defaultValue: "Puanınız:")
    public static let bookCommentsPlaceholder = localized(
        "bookComments.placeholder",
        defaultValue: "Bu kitap hakkındaki düşüncelerinizi paylaşın..."
    )
    public static let bookCommentsSubmit = localized("bookComments.submit", defaultValue: "Yorum Gönder")
    public static let bookCommentsEmpty = localized("bookComments.empty", defaultValue: "Henüz yorum yapılmamış.")
    public static let bookCommentsLoadFailed = localized("bookComments.loadFailed", defaultValue: "Yorumlar yüklenemedi.")
    public static let bookCommentsSubmitFailed = localized("bookComments.submitFailed", defaultValue: "Yorum gönderilemedi.")
    public static let bookCommentsReport = localized("bookComments.report", defaultValue: "Yorumu bildir")
    public static let bookCommentsLoginToComment = localized("bookComments.loginToComment", defaultValue: "Giriş")
    public static let bookCommentsSignedInSubtitle = localized(
        "bookComments.signedInSubtitle",
        defaultValue: "Kitap hakkındaki düşüncelerinizi paylaşın."
    )
    public static let bookCommentsGuestSubtitle = localized(
        "bookComments.guestSubtitle",
        defaultValue: "Yorum yazmak için üye olun veya giriş yapın."
    )
    public static let bookCommentsLoginRequiredTitle = localized("bookComments.loginRequiredTitle", defaultValue: "Giriş gerekli")
    public static let bookCommentsLoginRequiredMessage = localized("bookComments.loginRequiredMessage", defaultValue: "Yorum yazmak veya bildirmek için giriş yapın.")

    public static func bookCommentsRating(_ rating: Int) -> String {
        String(format: localized("bookComments.rating", defaultValue: "%d yıldız"), rating)
    }
    public static let directoryAuthorsTitle = localized("directory.authors.title", defaultValue: "Yazarlar")
    public static let directoryPublishersTitle = localized("directory.publishers.title", defaultValue: "Yayınevleri")
    public static let directoryLoading = localized("directory.loading", defaultValue: "Dizin yükleniyor")
    public static let directoryUnavailableTitle = localized("directory.unavailableTitle", defaultValue: "Dizin alınamadı")
    public static let directoryEmptyTitle = localized("directory.emptyTitle", defaultValue: "Sonuç bulunamadı")
    public static let directoryEmptyDescription = localized("directory.emptyDescription", defaultValue: "Aramanızı değiştirip yeniden deneyin.")
    public static let directorySearchPrompt = localized("directory.searchPrompt", defaultValue: "Ara")
    public static let directoryLoadFailed = localized("directory.loadFailed", defaultValue: "Yazar ve yayınevi bilgileri alınamadı.")
    public static let directoryStatEntries = localized("directory.stat.entries", defaultValue: "Kayıt")
    public static let directoryStatBooks = localized("directory.stat.books", defaultValue: "Kitap")
    public static let directorySortAscending = localized("directory.sort.ascending", defaultValue: "Alfabetik A-Z")
    public static let directorySortDescending = localized("directory.sort.descending", defaultValue: "Alfabetik Z-A")
    public static let directoryAuthorArchive = localized("directory.authorArchive", defaultValue: "Yazar Arşivi")
    public static let directoryPublisherArchive = localized("directory.publisherArchive", defaultValue: "Yayınevi Arşivi")
    public static func directoryHeroSubtitle(_ entries: Int, _ books: Int) -> String {
        String(format: localized("directory.heroSubtitle", defaultValue: "%1$d kayıt · %2$d kitap"), entries, books)
    }
    public static let commonLoadMore = localized("common.loadMore", defaultValue: "Daha fazla yükle")

    public static func directoryBookCount(_ count: Int) -> String {
        String(format: localized("directory.bookCount", defaultValue: "%d kitap"), count)
    }
    public static let downloadSecureConnectionRequired = localized("download.error.secureConnection", defaultValue: "Güvenli indirme bağlantısı gerekli.")
    public static let downloadServerRejected = localized("download.error.serverRejected", defaultValue: "Dosya indirilemedi.")
    public static let downloadValidationFailed = localized("download.error.validationFailed", defaultValue: "Dosya güvenli biçimde doğrulanamadı.")
    public static let downloadRemovalFailed = localized("download.error.removalFailed", defaultValue: "İndirme silinemedi.")

    public static let readerPreparing = localized("reader.preparing", defaultValue: "Okuma bağlantısı hazırlanıyor")
    public static let readerUnavailable = localized("reader.unavailable", defaultValue: "Okuyucu hazır değil")
    public static let readerAccessDenied = localized("reader.accessDenied", defaultValue: "Bu kitabı şu an okuyamazsınız.")
    public static let readerSecureLinkMissing = localized("reader.secureLinkMissing", defaultValue: "Güvenli geçici okuma bağlantısı alınamadı.")
    public static let readerInvalidBookId = localized("reader.invalidBookId", defaultValue: "Kitap kimliği geçersiz.")
    public static let readerAtsLinkMissing = localized("reader.atsLinkMissing", defaultValue: "App Store uyumlu güvenli okuma bağlantısı alınamadı.")
    public static let readerSessionFailed = localized("reader.sessionFailed", defaultValue: "Okuma oturumu başlatılamadı.")
    public static let readerUnsupportedFormat = localized("reader.unsupportedFormat", defaultValue: "Bu kitap biçimi desteklenmiyor.")
    public static let readerEPUBFormat = localized("reader.epub.format", defaultValue: "EPUB")
    public static let readerEPUBPreparing = localized("reader.epub.preparing", defaultValue: "EPUB hazırlanıyor")
    public static let readerEPUBUnavailable = localized("reader.epub.unavailable", defaultValue: "EPUB açılamadı")
    public static let readerEPUBOpenFailed = localized("reader.epub.openFailed", defaultValue: "EPUB dosyası güvenli biçimde indirilemedi veya açılamadı.")
    public static let readerAddBookmark = localized("reader.addBookmark", defaultValue: "Bu sayfaya yer imi ekle")
    public static let readerRemoveBookmark = localized("reader.removeBookmark", defaultValue: "Bu sayfadaki yer imini kaldır")
    public static let readerBookmarks = localized("reader.bookmarks", defaultValue: "Yer İmleri")
    public static let readerBookmarksEmpty = localized("reader.bookmarks.empty", defaultValue: "Yer imi yok")
    public static let readerBookmarksEmptyDescription = localized("reader.bookmarks.emptyDescription", defaultValue: "Kaydetmek istediğiniz sayfada yer imi düğmesine dokunun.")
    public static let readerPages = localized("reader.pages", defaultValue: "Sayfalar")
    public static let readerPreviousPage = localized("reader.previousPage", defaultValue: "Önceki sayfa")
    public static let readerNextPage = localized("reader.nextPage", defaultValue: "Sonraki sayfa")
    public static let readerPageSlider = localized("reader.pageSlider", defaultValue: "Sayfa seçici")
    public static let readerLayout = localized("reader.layout", defaultValue: "Okuma düzeni")
    public static let readerContinuousLayout = localized("reader.layout.continuous", defaultValue: "Dikey sürekli")
    public static let readerPagedLayout = localized("reader.layout.paged", defaultValue: "Sayfa sayfa")
    public static let readerSettings = localized("reader.settings", defaultValue: "Okuyucu ayarları")
    public static let readerSettingsAppearance = localized("reader.settings.appearance", defaultValue: "Görünüm")
    public static let readerSettingsBookInfo = localized("reader.settings.bookInfo", defaultValue: "Kitap bilgisi")
    public static let readerSettingsFormat = localized("reader.settings.format", defaultValue: "Biçim")
    public static let readerSettingsSecureConnection = localized("reader.settings.secureConnection", defaultValue: "Güvenli bağlantı")
    public static let readerSettingsActive = localized("reader.settings.active", defaultValue: "Aktif")
    public static let readerSettingsEPUBNote = localized("reader.settings.epubNote", defaultValue: "EPUB görünümü Readium tarafından yönetilir.")
    public static let readerSettingsPDFNote = localized("reader.settings.pdfNote", defaultValue: "PDF sayfaları arasında geçiş biçimini seçin.")
    public static let readerSyncReady = localized("reader.sync.ready", defaultValue: "Sunucu bağlantısı hazır")
    public static let readerSyncSaving = localized("reader.sync.saving", defaultValue: "Sunucuya kaydediliyor")
    public static let readerSyncSaved = localized("reader.sync.saved", defaultValue: "Sunucuya kaydedildi")
    public static let readerSyncPending = localized("reader.sync.pending", defaultValue: "Senkronizasyon bekliyor")

    public static func readerPage(_ current: Int, _ total: Int) -> String {
        String(format: localized("reader.page", defaultValue: "Sayfa %d / %d"), current, total)
    }

    public static func readerPageNumber(_ page: Int) -> String {
        String(format: localized("reader.pageNumber", defaultValue: "Sayfa %d"), page)
    }

    public static let deleteAccountTitle = localized("account.delete.title", defaultValue: "Hesabı Sil")
    public static let deleteAccountWarning = localized("account.delete.warning", defaultValue: "Bu işlem tüm hesabınızın silinmesi sürecini başlatır. Talep genellikle 30 gün içinde tamamlanır ve sonuç kayıtlı e-posta adresinize bildirilir. Profil, kitaplık ve kullanıcı içerikleri silinir veya yasal zorunluluk varsa anonimleştirilir. Apple aboneliğiniz varsa ayrıca App Store aboneliklerinizi yönetin.")
    public static let deleteAccountConfirmationPrompt = localized("account.delete.confirmationPrompt", defaultValue: "Devam etmek için SIL yazın.")
    public static let deleteAccountConfirmationPlaceholder = localized("account.delete.confirmationPlaceholder", defaultValue: "SIL")
    public static let deleteAccountPasswordPlaceholder = localized("account.delete.passwordPlaceholder", defaultValue: "Mevcut şifre (Apple hesabında boş bırakın)")
    public static let deleteAccountReasonLabel = localized("account.delete.reasonLabel", defaultValue: "Silme nedeni")
    public static let deleteAccountSubmit = localized("account.delete.submit", defaultValue: "Silme talebi gönder")
    public static let deleteAccountSubmitted = localized("account.delete.submitted", defaultValue: "Hesap silme talebiniz alındı. İşlem genellikle 30 gün içinde tamamlanır ve e-postayla bildirilir.")
    public static let deleteAccountSubmitFailed = localized("account.delete.submitFailed", defaultValue: "Hesap silme talebi gönderilemedi.")

    public static let accountSecurityTitle = localized("account.security.title", defaultValue: "Giriş ve Güvenlik")
    public static let accountSecurityEmailSection = localized("account.security.email.section", defaultValue: "E-posta")
    public static let accountSecurityCurrentEmail = localized("account.security.email.current", defaultValue: "Mevcut e-posta")
    public static let accountSecurityNewEmail = localized("account.security.email.new", defaultValue: "Yeni e-posta")
    public static let accountSecurityCurrentPassword = localized("account.security.currentPassword", defaultValue: "Mevcut şifre")
    public static let accountSecurityUpdateEmail = localized("account.security.email.update", defaultValue: "E-postayı güncelle")
    public static let accountSecurityEmailFooter = localized("account.security.email.footer", defaultValue: "Güvenlik için mevcut şifreniz yeniden doğrulanır. Yeni adres için e-posta onayı gerekebilir.")
    public static let accountSecurityEmailUpdated = localized("account.security.email.updated", defaultValue: "E-posta adresiniz güncellendi.")
    public static let accountSecurityEmailConfirmation = localized("account.security.email.confirmation", defaultValue: "Yeni adresinize gönderilen doğrulama bağlantısını açın.")
    public static let accountSecurityEmailFailed = localized("account.security.email.failed", defaultValue: "E-posta güncellenemedi. Mevcut şifrenizi ve adresi kontrol edin.")
    public static let accountSecurityPasswordSection = localized("account.security.password.section", defaultValue: "Şifre")
    public static let accountSecurityNewPassword = localized("account.security.password.new", defaultValue: "Yeni şifre")
    public static let accountSecurityConfirmPassword = localized("account.security.password.confirm", defaultValue: "Yeni şifre tekrar")
    public static let accountSecurityUpdatePassword = localized("account.security.password.update", defaultValue: "Şifreyi güncelle")
    public static let accountSecurityPasswordFooter = localized("account.security.password.footer", defaultValue: "Şifre değişince diğer mobil oturumlar kapatılır ve bu cihaz için güvenli oturum yenilenir.")
    public static let accountSecurityPasswordUpdated = localized("account.security.password.updated", defaultValue: "Şifreniz ve bu cihazdaki güvenli oturum yenilendi.")
    public static let accountSecurityPasswordFailed = localized("account.security.password.failed", defaultValue: "Şifre güncellenemedi. Mevcut şifrenizi ve yeni şifre kurallarını kontrol edin.")
    public static let accountSecuritySaving = localized("account.security.saving", defaultValue: "Güncelleniyor")

    public static let privacyTitle = localized("privacy.title", defaultValue: "Gizlilik")
    public static let privacyAnalyticsOptIn = localized("privacy.analyticsOptIn", defaultValue: "Kullanım analitiğine izin ver")
    public static let privacyNotificationPreviews = localized("privacy.notificationPreviews", defaultValue: "Bildirim önizlemelerini göster")
    public static let privacyTrackingNotice = localized("privacy.trackingNotice", defaultValue: "Bu uygulama reklam takibi yapacak şekilde tasarlanmamıştır. Analitik etkinleştirilirse App Store gizlilik etiketleri buna göre güncellenmelidir.")
    public static let privacyDataSection = localized("privacy.dataSection", defaultValue: "Veri")
    public static let privacyDataNotice = localized("privacy.dataNotice", defaultValue: "Okuma ilerlemesi, kitaplık, yorumlar ve hesap bilgileri Ekitaplığım hesabınızla ilişkilidir. Hesap silme talebi Hesap bölümünden başlatılır.")
    public static let privacySummarySection = localized("privacy.summarySection", defaultValue: "Gizlilik Özeti")
    public static let privacyTrackingLabel = localized("privacy.trackingLabel", defaultValue: "Uygulamalar arası takip")
    public static let privacyAnalyticsLabel = localized("privacy.analyticsLabel", defaultValue: "Üçüncü taraf analitik")
    public static let privacyAdvertisingLabel = localized("privacy.advertisingLabel", defaultValue: "Reklam SDK'sı")
    public static let privacyNotUsed = localized("privacy.notUsed", defaultValue: "Kullanılmıyor")
    public static let privacyOfflineNotice = localized("privacy.offlineNotice", defaultValue: "İndirilen kitaplar yalnızca uygulama alanında tutulur, cihaz yedeğine eklenmez ve siz kaldırana kadar saklanır.")

    public static let reportTitle = localized("report.title", defaultValue: "İçerik bildir")
    public static let reportReason = localized("report.reason", defaultValue: "Neden")
    public static let reportObjectionable = localized("report.reason.objectionable", defaultValue: "Uygunsuz içerik")
    public static let reportCopyright = localized("report.reason.copyright", defaultValue: "Telif hakkı")
    public static let reportBrokenFile = localized("report.reason.brokenFile", defaultValue: "Bozuk dosya")
    public static let reportOther = localized("report.reason.other", defaultValue: "Diğer")
    public static let reportMessageLabel = localized("report.messageLabel", defaultValue: "Rapor açıklaması")
    public static let reportFooter = localized("report.footer", defaultValue: "Raporlar moderasyon ekibine gönderilir. Kötüye kullanım bildirimleri güvenlik amacıyla incelenir.")
    public static let reportSubmit = localized("report.submit", defaultValue: "Raporu gönder")
    public static let bookDetailIssueBrokenLinkReportTitle = localized(
        "book.detail.issueBrokenLinkReportTitle",
        defaultValue: "Kırık link bildir"
    )
    public static let bookDetailIssueBrokenLinkReportDescription = localized(
        "book.detail.issueBrokenLinkReportDescription",
        defaultValue: "Okuma veya indirme bağlantısında sorun varsa admin ekibine iletin."
    )
    public static let bookDetailIssueBrokenLinkReportPlaceholder = localized(
        "book.detail.issueBrokenLinkReportPlaceholder",
        defaultValue: "Örn. PDF açılmıyor veya dosya indirilemiyor."
    )
    public static let bookDetailIssueMissingCoverReportTitle = localized(
        "book.detail.issueMissingCoverReportTitle",
        defaultValue: "Eksik kapak bildir"
    )
    public static let bookDetailIssueMissingCoverReportDescription = localized(
        "book.detail.issueMissingCoverReportDescription",
        defaultValue: "Kapak görseli eksik, hatalı veya bozuk görünüyorsa bildirin."
    )
    public static let bookDetailIssueMissingCoverReportPlaceholder = localized(
        "book.detail.issueMissingCoverReportPlaceholder",
        defaultValue: "Örn. Kapak görünmüyor veya yanlış kitap kapağı geliyor."
    )
    public static let bookDetailIssueCopyrightReportTitle = localized(
        "book.detail.issueCopyrightReportTitle",
        defaultValue: "Telif bildirimi gönder"
    )
    public static let bookDetailIssueCopyrightReportDescription = localized(
        "book.detail.issueCopyrightReportDescription",
        defaultValue: "Telif veya hak sahipliğiyle ilgili bildiriminizi admin ekibine iletin."
    )
    public static let bookDetailIssueCopyrightReportPlaceholder = localized(
        "book.detail.issueCopyrightReportPlaceholder",
        defaultValue: "Hak sahipliği, temsil durumu veya talebinize dair kısa açıklama yazın."
    )
    public static let forumThreadReportDescription = localized(
        "forumThread.reportDescription",
        defaultValue: "Bu forum mesajında spam, hakaret, telif ihlali veya uygunsuz içerik olduğunu düşünüyorsanız yönetime bildirin."
    )
    public static let forumThreadReportPlaceholder = localized(
        "forumThread.reportPlaceholder",
        defaultValue: "Kısa açıklama yazın..."
    )
    public static let forumThreadReportSubmit = localized("forumThread.reportSubmit", defaultValue: "Raporla")
    public static let commonClose = localized("common.close", defaultValue: "Kapat")
    public static let commonShare = localized("common.share", defaultValue: "Paylaş")
    public static let commonRemove = localized("common.remove", defaultValue: "Sil")
    public static let commonCancel = localized("common.cancel", defaultValue: "İptal")
    public static let commonSuccess = localized("common.success", defaultValue: "Başarılı")
    public static let commonSubmit = localized("common.submit", defaultValue: "Gönder")
    public static let commonRetry = localized("common.retry", defaultValue: "Tekrar dene")
    public static let reportSubmitted = localized("report.submitted", defaultValue: "Raporunuz alındı.")
    public static let reportSubmitFailed = localized("report.submitFailed", defaultValue: "Rapor gönderilemedi.")

    public static let bookRequestsTitle = localized("bookRequests.title", defaultValue: "Kitap İstekleri")
    public static let bookRequestsHeroTitle = localized("bookRequests.heroTitle", defaultValue: "Sosyal & Topluluk")
    public static let bookRequestsHeroSubtitle = localized(
        "bookRequests.heroSubtitle",
        defaultValue: "Ortak okuma gruplarına katıl,\nkütüphaneye yeni kitap iste!"
    )
    public static let bookRequestsLoading = localized("bookRequests.loading", defaultValue: "Kitap istekleri yükleniyor")
    public static let bookRequestsUnavailableTitle = localized("bookRequests.unavailableTitle", defaultValue: "İstekler alınamadı")
    public static let bookRequestsEmptyTitle = localized("bookRequests.emptyTitle", defaultValue: "Henüz kitap isteği yapılmamış.")
    public static let bookRequestsEmptyDescription = localized("bookRequests.emptyDescription", defaultValue: "Aradığınız kitabı ilk siz isteyebilirsiniz.")
    public static let bookRequestsGuestCreateHint = localized(
        "bookRequests.guestCreateHint",
        defaultValue: "İstek göndermek için önce giriş yapmalısınız."
    )
    public static let bookRequestsCreated = localized("bookRequests.created", defaultValue: "Kitap isteğiniz gönderildi.")
    public static let bookRequestsVoteSaved = localized("bookRequests.voteSaved", defaultValue: "Oyunuz kaydedildi.")
    public static let bookRequestsCreate = localized("bookRequests.create", defaultValue: "Yeni kitap isteği")
    public static let bookRequestsCreateDialogTitle = localized("bookRequests.createDialogTitle", defaultValue: "Yeni Kitap İstemi Yap")
    public static let bookRequestsListSection = localized("bookRequests.listSection", defaultValue: "Kitap İstek Listesi")
    public static let bookRequestsRequestAction = localized("bookRequests.requestAction", defaultValue: "İstekte Bulun")
    public static let bookRequestsBookTitle = localized("bookRequests.bookTitle", defaultValue: "Kitap Adı")
    public static let bookRequestsAuthor = localized("bookRequests.author", defaultValue: "Yazar")
    public static let bookRequestsAuthorMissing = localized("bookRequests.authorMissing", defaultValue: "Belirtilmemiş")
    public static func bookRequestsAuthorLine(_ author: String) -> String {
        let value = author.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(
            format: localized("bookRequests.authorLine", defaultValue: "Yazar: %@"),
            value.isEmpty ? bookRequestsAuthorMissing : value
        )
    }
    public static let bookRequestsISBN = localized("bookRequests.isbn", defaultValue: "ISBN (Opsiyonel)")
    public static let bookRequestsSubmitting = localized("bookRequests.submitting", defaultValue: "Gönderiliyor...")
    public static let bookRequestsLoadFailed = localized("bookRequests.loadFailed", defaultValue: "Kitap istekleri yüklenemedi.")
    public static let bookRequestsCreateFailed = localized("bookRequests.createFailed", defaultValue: "Kitap isteği gönderilemedi.")
    public static let bookRequestsVoteFailed = localized("bookRequests.voteFailed", defaultValue: "Oy işlemi tamamlanamadı.")
    public static let bookRequestsActionFailedTitle = localized("bookRequests.actionFailedTitle", defaultValue: "İşlem tamamlanamadı")
    public static let bookRequestsActionFailedMessage = localized("bookRequests.actionFailedMessage", defaultValue: "Lütfen yeniden deneyin.")
    public static let bookRequestsLoginRequiredTitle = localized("bookRequests.loginRequiredTitle", defaultValue: "Giriş gerekli")
    public static let bookRequestsLoginRequiredMessage = localized("bookRequests.loginRequiredMessage", defaultValue: "Kitap isteği göndermek veya oy vermek için giriş yapın.")
    public static let bookRequestsGoToLogin = localized("bookRequests.goToLogin", defaultValue: "Girişe git")

    public static func bookRequestsRequestedBy(_ username: String) -> String {
        String(format: localized("bookRequests.requestedBy", defaultValue: "İsteyen: %@"), username)
    }

    public static func bookRequestsVoteCount(_ count: Int) -> String {
        // Match Android SocialScreen vote affordance: "${voteCount} Oy"
        String(format: localized("bookRequests.voteCount", defaultValue: "%d Oy"), count)
    }

    public static let bookRequestsVoteAccessibility = localized("bookRequests.voteAccessibility", defaultValue: "Upvote")

    public static func bookRequestsStatus(_ status: String) -> String {
        switch status.uppercased() {
        case "ACQUIRED": localized("bookRequests.status.acquired", defaultValue: "Temin Edildi")
        case "REJECTED": localized("bookRequests.status.rejected", defaultValue: "Uygun Bulunmadı")
        default: localized("bookRequests.status.pending", defaultValue: "Oylanıyor")
        }
    }

    public static let conversationsTitle = localized("conversations.title", defaultValue: "Mesajlar")
    public static let conversationsLoading = localized("conversations.loading", defaultValue: "Mesajlar yükleniyor")
    public static let conversationsUnavailableTitle = localized("conversations.unavailableTitle", defaultValue: "Mesajlar alınamadı")
    public static let conversationsEmptyTitle = localized("conversations.emptyTitle", defaultValue: "Henüz mesaj yok")
    public static let conversationsEmptyDescription = localized("conversations.emptyDescription", defaultValue: "Yeni bir özel konuşma başlatabilirsiniz.")
    public static let conversationsLoadFailed = localized("conversations.loadFailed", defaultValue: "Özel mesajlar yüklenemedi.")
    public static let conversationsNew = localized("conversations.new", defaultValue: "Yeni mesaj")
    public static let conversationsMessageTitle = localized("conversations.messageTitle", defaultValue: "Mesaj")
    public static let conversationsReplyPlaceholder = localized("conversations.replyPlaceholder", defaultValue: "Yanıt yazın")
    public static let conversationsRecipient = localized("conversations.recipient", defaultValue: "Alıcı kullanıcı adı")
    public static let conversationsSubject = localized("conversations.subject", defaultValue: "Konu")
    public static let conversationsMessageBody = localized("conversations.messageBody", defaultValue: "Mesaj")
    public static let conversationsSending = localized("conversations.sending", defaultValue: "Gönderiliyor")
    public static let conversationsSendFailedTitle = localized("conversations.sendFailedTitle", defaultValue: "Mesaj gönderilemedi")
    public static let conversationsSendFailed = localized("conversations.sendFailed", defaultValue: "Mesaj gönderilemedi. Alıcıyı ve izinlerinizi kontrol edip yeniden deneyin.")
    public static let conversationsYou = localized("conversations.you", defaultValue: "Siz")
    public static let conversationsStarred = localized("conversations.starred", defaultValue: "Yıldızlı")

    public static let myCommentsTitle = localized("myComments.title", defaultValue: "Yorumlarım")
    public static let myCommentsLoading = localized("myComments.loading", defaultValue: "Yorumlar yükleniyor")
    public static let myCommentsUnavailableTitle = localized("myComments.unavailableTitle", defaultValue: "Yorumlar alınamadı")
    public static let myCommentsEmptyTitle = localized("myComments.emptyTitle", defaultValue: "Henüz yorum yok")
    public static let myCommentsEmptyDescription = localized("myComments.emptyDescription", defaultValue: "Forumlarda yaptığınız yorumlar burada gösterilir.")
    public static let myCommentsForumTitle = localized("myComments.forumTitle", defaultValue: "Forum konusu")

    public static func conversationsReplyCount(_ count: Int) -> String {
        String(format: localized("conversations.replyCount", defaultValue: "%d yanıt"), count)
    }

    public static let membersTitle = localized("members.title", defaultValue: "Üyeler")
    public static let membersLoading = localized("members.loading", defaultValue: "Üyeler yükleniyor")
    public static let membersUnavailableTitle = localized("members.unavailableTitle", defaultValue: "Üyeler alınamadı")
    public static let membersEmptyTitle = localized("members.emptyTitle", defaultValue: "Üye bulunamadı")
    public static let membersEmptyDescription = localized("members.emptyDescription", defaultValue: "Aramanızı değiştirip yeniden deneyin.")
    public static let membersLoadFailed = localized("members.loadFailed", defaultValue: "Üye dizini yüklenemedi.")
    public static let membersSearchPrompt = localized("members.searchPrompt", defaultValue: "Kullanıcı ara")
    public static let membersTotalLabel = localized("members.totalLabel", defaultValue: "Toplam üye")
    public static let membersSortLabel = localized("members.sortLabel", defaultValue: "Sıralama")
    public static let membersSortAlphabetical = localized("members.sort.alphabetical", defaultValue: "Alfabetik")
    public static let membersSortNewest = localized("members.sort.newest", defaultValue: "En yeni")
    public static let membersSortActive = localized("members.sort.active", defaultValue: "En aktif")
    public static let membersVerified = localized("members.verified", defaultValue: "Doğrulanmış üye")
    public static let membersProfileTitle = localized("members.profileTitle", defaultValue: "Üye Profili")
    public static let membersProfileLoading = localized("members.profileLoading", defaultValue: "Profil yükleniyor")
    public static let membersProfileLoadFailed = localized("members.profileLoadFailed", defaultValue: "Üye profili yüklenemedi.")
    public static let membersStatsSection = localized("members.statsSection", defaultValue: "İstatistikler")
    public static let membersMessagesLabel = localized("members.messagesLabel", defaultValue: "Mesajlar")
    public static let membersReactionsLabel = localized("members.reactionsLabel", defaultValue: "Tepki puanı")
    public static let membersJoinedLabel = localized("members.joinedLabel", defaultValue: "Katılım")
    public static let membersAboutSection = localized("members.aboutSection", defaultValue: "Hakkında")
    public static let membersLocationLabel = localized("members.locationLabel", defaultValue: "Konum")
    public static let membersActionsSection = localized("members.actionsSection", defaultValue: "İşlemler")
    public static let membersFollow = localized("members.follow", defaultValue: "Takip et")
    public static let membersUnfollow = localized("members.unfollow", defaultValue: "Takibi bırak")
    public static let membersBlock = localized("members.block", defaultValue: "Üyeyi engelle")
    public static let membersBlockConfirmation = localized("members.blockConfirmation", defaultValue: "Bu üyeyi engellemek istiyor musunuz?")
    public static let membersBlockCompleted = localized("members.blockCompleted", defaultValue: "Üye engellendi")
    public static let membersActionFailed = localized("members.actionFailed", defaultValue: "Üye işlemi tamamlanamadı.")
    public static let membersSendMessage = localized("members.sendMessage", defaultValue: "Mesaj gönder")
    public static let membersLibraryHidden = localized("members.libraryHidden", defaultValue: "Bu üyenin rafı gizli.")
    public static let membersLastReadTitle = localized("members.lastReadTitle", defaultValue: "Son okuduğu kitap")
    public static let membersShelvesTitle = localized("members.shelvesTitle", defaultValue: "Rafları")
    public static let membersRecentBooksTitle = localized("members.recentBooksTitle", defaultValue: "Okuduğu kitaplar")
    public static let membersLoginForActions = localized("members.loginForActions", defaultValue: "Takip ve mesaj için giriş yapmalısınız.")
    public static let membersStatReading = localized("members.statReading", defaultValue: "Okuyor")
    public static let membersStatRead = localized("members.statRead", defaultValue: "Okudu")
    public static let membersStatListed = localized("members.statListed", defaultValue: "Listede")
    public static let membersTabProfile = localized("members.tab.profile", defaultValue: "Profil")
    public static let membersTabLibrary = localized("members.tab.library", defaultValue: "Kütüphane")
    public static let membersTabAbout = localized("members.tab.about", defaultValue: "Hakkında")
    public static let membersTabActivity = localized("members.tab.activity", defaultValue: "Son Aktivite")
    public static let membersShelfReading = localized("members.shelf.reading", defaultValue: "Şu anda okuyor")
    public static let membersShelfFinished = localized("members.shelf.finished", defaultValue: "Okuduğu kitaplar")
    public static let membersShelfWantToRead = localized("members.shelf.wantToRead", defaultValue: "Okuyacakları")
    public static let membersShelfFavorites = localized("members.shelf.favorites", defaultValue: "Favorileri")
    public static let membersShelfEmpty = localized("members.shelf.empty", defaultValue: "Bu rafta kitap yok.")
    public static let membersNoSharedBooks = localized("members.noSharedBooks", defaultValue: "Bu üyenin paylaşılmış kitabı yok.")
    public static let membersFollowingBadge = localized("members.followingBadge", defaultValue: "Takip ediliyor")
    public static let membersBlockedBadge = localized("members.blockedBadge", defaultValue: "Engellendi")
    public static let membersMessagePrompt = localized("members.messagePrompt", defaultValue: "Mesajınızı yazın")
    public static let membersMessageFailed = localized("members.messageFailed", defaultValue: "Mesaj gönderilemedi.")
    public static let communityDirectorySection = localized("community.directorySection", defaultValue: "Üyeler")

    public static func membersMessageCount(_ count: Int) -> String {
        String(format: localized("members.messageCount", defaultValue: "%d mesaj"), count)
    }

    public static let termsTitle = localized("terms.title", defaultValue: "Topluluk Kuralları")
    public static let termsIntro = localized("terms.intro", defaultValue: "Topluluk alanlarında paylaşım yapmadan önce kullanım şartlarını ve topluluk kurallarını kabul etmelisiniz.")
    public static let termsOpen = localized("terms.open", defaultValue: "Kullanım şartlarını aç")
    public static let termsAcceptToggle = localized("terms.acceptToggle", defaultValue: "Topluluk kurallarını kabul ediyorum")
    public static let termsFooter = localized("terms.footer", defaultValue: "Uygunsuz içerik, taciz, telif ihlali, spam veya kişisel veri paylaşımı kabul edilmez.")
    public static let termsAccept = localized("terms.accept", defaultValue: "Kabul et")
    public static let termsAccepted = localized("terms.accepted", defaultValue: "Topluluk kuralları kabul edildi.")
    public static let termsAcceptFailed = localized("terms.acceptFailed", defaultValue: "Kabul durumu kaydedilemedi.")

    public static let tabHome = localized("tab.home", defaultValue: "Ana sayfa")
    public static let tabCatalog = localized("tab.catalog", defaultValue: "Kitaplar")
    public static let tabLibrary = localized("tab.library", defaultValue: "Kütüphane")
    public static let tabCommunity = localized("tab.community", defaultValue: "Topluluk")
    public static let tabAccount = localized("tab.account", defaultValue: "Hesap")
    public static let menuTitle = localized("menu.title", defaultValue: "Menü")
    public static let menuSubtitle = localized("menu.subtitle", defaultValue: "Kitap, forum ve okuma alanın")
    public static let menuAuthorsSubtitle = localized("menu.authorsSubtitle", defaultValue: "Yazar arşivi ve eserleri")
    public static let menuPublishersSubtitle = localized("menu.publishersSubtitle", defaultValue: "Yayınevlerine göre keşfet")
    public static let menuRequestsSubtitle = localized("menu.requestsSubtitle", defaultValue: "İstekleri incele ve oy ver")

    public static let homeTitle = localized("home.title", defaultValue: "Ekitaplığım")
    public static let homeOpenCatalog = localized("home.openCatalog", defaultValue: "Kitap kataloğunu aç")
    public static let homeContinueReading = localized("home.continueReading", defaultValue: "Kaldığım yerden devam et")
    public static let homeStatsSection = localized("home.stats.section", defaultValue: "Ekitaplığım")
    public static let homeExploreSection = localized("home.explore.section", defaultValue: "Keşfet")
    public static let homeStatsLoading = localized("home.stats.loading", defaultValue: "İstatistikler yükleniyor")
    public static let homeStatsLoadFailed = localized("home.stats.loadFailed", defaultValue: "Site istatistikleri alınamadı.")
    public static let homeBooks = localized("home.stats.books", defaultValue: "E-kitap")
    public static let homeAuthors = localized("home.stats.authors", defaultValue: "Yazar")
    public static let homePublishers = localized("home.stats.publishers", defaultValue: "Yayınevi")
    public static let homeCategories = localized("home.stats.categories", defaultValue: "Kategori")
    public static let homeSearchPrompt = localized("home.searchPrompt", defaultValue: "Kitap, yazar, yayınevi veya ISBN ara...")
    public static let homePopularBooks = localized("home.popularBooks", defaultValue: "Popüler Kitaplar")
    public static let homePopularBooksSubtitle = localized("home.popularBooksSubtitle", defaultValue: "Okurların en çok ilgi gösterdiği kitaplar")
    public static let homeNewestBooks = localized("home.newestBooks", defaultValue: "Yeni Eklenenler")
    public static let homeNewestBooksSubtitle = localized("home.newestBooksSubtitle", defaultValue: "Kütüphaneye yeni katılan eserler")
    public static let homeSeeAll = localized("home.seeAll", defaultValue: "Tümünü gör")
    public static let homeCommunitySubtitle = localized("home.communitySubtitle", defaultValue: "Kitaplar üzerine konuş, paylaş ve keşfet")
    public static let premiumShortTitle = localized("premium.shortTitle", defaultValue: "Premium")

    public static func homeStatAccessibility(_ label: String, _ value: Int) -> String {
        String(format: localized("home.stats.accessibility", defaultValue: "%@: %d"), label, value)
    }

    public static let loginTitle = localized("login.title", defaultValue: "Giriş")
    public static let loginUsernamePlaceholder = localized("login.usernamePlaceholder", defaultValue: "Kullanıcı Adı veya E-posta")
    public static let loginPasswordPlaceholder = localized("login.passwordPlaceholder", defaultValue: "Şifre")
    public static let loginSubmit = localized("login.submit", defaultValue: "Giriş Yap")
    public static let loginInvalidCredentials = localized("login.invalidCredentials", defaultValue: "Kullanıcı adı veya şifre doğrulanamadı.")
    public static let loginAppleInvalid = localized("login.appleInvalid", defaultValue: "Apple ile giriş doğrulanamadı.")
    public static let loginAppleFailed = localized("login.appleFailed", defaultValue: "Apple ile giriş tamamlanamadı.")
    public static let loginGoogleSignIn = localized("login.google.signIn", defaultValue: "Google ile giriş")
    public static let loginGoogleRegister = localized("login.google.register", defaultValue: "Google ile kayıt ol")
    public static let loginOrDivider = localized("login.orDivider", defaultValue: "veya")
    public static let loginGoogleFailed = localized("login.google.failed", defaultValue: "Google ile giriş tamamlanamadı.")
    public static let loginGoogleUnavailable = localized("login.google.unavailable", defaultValue: "Google ile giriş şu anda kullanılamıyor.")
    public static let loginGoogleUsernameTitle = localized("login.google.usernameTitle", defaultValue: "Kullanıcı Adı Seçin")
    public static let loginGoogleUsernameMessage = localized("login.google.usernameMessage", defaultValue: "Google ile kayıt olmak için forumda kullanacağınız bir kullanıcı adı belirleyin.")
    public static let loginGoogleUsernamePlaceholder = localized("login.google.usernamePlaceholder", defaultValue: "Kullanıcı Adı")
    public static let loginGoogleUsernameRequired = localized("login.google.usernameRequired", defaultValue: "Kullanıcı adı zorunludur.")
    public static let loginGoogleRegistrationFailed = localized("login.google.registrationFailed", defaultValue: "Google ile kayıt tamamlanamadı.")
    public static let loginModePicker = localized("login.modePicker", defaultValue: "Hesap işlemi")
    public static let loginModeLogin = localized("login.mode.login", defaultValue: "Giriş")
    public static let loginModeRegister = localized("login.mode.register", defaultValue: "Kayıt Ol")
    public static let loginRegisterTitle = localized("login.register.title", defaultValue: "Yeni Hesap Oluştur")
    public static let loginRegisterSubmit = localized("login.register.submit", defaultValue: "Kayıt Ol")
    public static let loginRegisterFailed = localized("login.register.failed", defaultValue: "Kayıt tamamlanamadı. Bilgilerinizi kontrol edip yeniden deneyin.")
    public static let loginEmailPlaceholder = localized("login.emailPlaceholder", defaultValue: "E-posta Adresi")
    public static let loginPasswordConfirmation = localized("login.passwordConfirmation", defaultValue: "Şifre Tekrar")
    public static let loginPasswordsMismatch = localized("login.passwordsMismatch", defaultValue: "Şifreler eşleşmiyor.")
    public static let loginAcceptLegal = localized("login.acceptLegal", defaultValue: "Kullanım şartlarını ve gizlilik politikasını kabul ediyorum")
    public static let loginAcceptLegalBody = localized(
        "login.acceptLegalBody",
        defaultValue: "Hesap oluşturarak E-Kitaplığım Kullanım Şartları ve Gizlilik Politikası'nı kabul ediyorum."
    )
    public static let loginEULA = localized("login.eula", defaultValue: "Son Kullanıcı Lisans Sözleşmesi (EULA)")
    public static let loginLegalLoading = localized("login.legalLoading", defaultValue: "Güncel şartlar yükleniyor…")
    public static let loginLegalUnavailable = localized("login.legalUnavailable", defaultValue: "Güncel şartlar yüklenemedi. Giriş ve kayıt geçici olarak kullanılamıyor.")
    public static let loginCommunityRulesSummary = localized("login.communityRulesSummary", defaultValue: "Nefret, taciz, cinsel içerik, şiddet, spam ve kişisel bilgi paylaşımı yasaktır. İhlaller bildirilebilir ve kullanıcılar engellenebilir.")
    public static let loginForgotPassword = localized("login.forgotPassword", defaultValue: "Şifremi Unuttum")
    public static let loginResetTitle = localized("login.reset.title", defaultValue: "Şifre Sıfırlama")
    public static let loginResetSubmit = localized("login.reset.submit", defaultValue: "Sıfırlama Bağlantısı Gönder")
    public static let loginResetSubmitted = localized("login.reset.submitted", defaultValue: "Bu e-posta kayıtlıysa sıfırlama bağlantısı gönderildi.")
    public static let loginResetFailed = localized("login.reset.failed", defaultValue: "Şifre sıfırlama isteği gönderilemedi.")
    public static let loginResetPrivacyNotice = localized("login.reset.privacyNotice", defaultValue: "Güvenlik nedeniyle e-posta adresinin kayıtlı olup olmadığı açıklanmaz.")
    public static let loginBackToLogin = localized("login.backToLogin", defaultValue: "Giriş Ekranına Dön")
    public static let loginCommunityTagline = localized("login.communityTagline", defaultValue: "Ekitaplığım Kütüphane Topluluğu")
    public static let loginSignalShelf = localized("login.signal.shelf", defaultValue: "Raf senkronu")
    public static let loginSignalChat = localized("login.signal.chat", defaultValue: "Canlı Sohbet")
    public static let loginSignalPremium = localized("login.signal.premium", defaultValue: "Premium erişim")
    public static let loginBadgeLogin = localized("login.badge.login", defaultValue: "Üye girişi")
    public static let loginBadgeRegister = localized("login.badge.register", defaultValue: "Yeni üyelik")
    public static let loginBadgeReset = localized("login.badge.reset", defaultValue: "Hesap kurtarma")
    public static let loginHeadingLogin = localized("login.heading.login", defaultValue: "Giriş Yap")
    public static let loginSubtitleLogin = localized(
        "login.subtitle.login",
        defaultValue: "Kitaplığın, favorilerin ve günlük limitlerin tek hesapta senkronize olsun."
    )
    public static let loginSubtitleRegister = localized(
        "login.subtitle.register",
        defaultValue: "Kitap raflarını ve okuma limitlerini hesabınla güvenle eşleştir."
    )
    public static let loginSubtitleReset = localized(
        "login.subtitle.reset",
        defaultValue: "E-posta adresine şifre sıfırlama bağlantısı gönderelim."
    )
    public static let loginSwitchToRegister = localized("login.switchToRegister", defaultValue: "Henüz hesabınız yok mu? Kayıt olun")
    public static let loginSwitchToLogin = localized("login.switchToLogin", defaultValue: "Zaten hesabınız var mı? Giriş yapın")
    public static let loginShowPassword = localized("login.showPassword", defaultValue: "Şifreyi göster")
    public static let loginHidePassword = localized("login.hidePassword", defaultValue: "Şifreyi gizle")

    public static let settingsTitle = localized("settings.title", defaultValue: "Hesap")
    public static let settingsUser = localized("settings.user", defaultValue: "Kullanıcı")
    public static let settingsSigningIn = localized("settings.signingIn", defaultValue: "Giriş yapılıyor")
    public static let settingsSignOut = localized("settings.signOut", defaultValue: "Çıkış yap")
    public static let settingsSignIn = localized("settings.signIn", defaultValue: "Giriş yap")
    public static let settingsProfileSection = localized("settings.profileSection", defaultValue: "Profil")
    public static let settingsProfile = localized("settings.profile", defaultValue: "Profilim")
    public static let settingsNotifications = localized("settings.notifications", defaultValue: "Bildirimler")
    public static let settingsAccountSection = localized("settings.accountSection", defaultValue: "Hesap")
    public static let settingsStartAccountDeletion = localized("settings.startAccountDeletion", defaultValue: "Hesap silme talebi başlat")
    public static let settingsLegalSection = localized("settings.legalSection", defaultValue: "Yasal")
    public static let settingsPrivacyPolicy = localized("settings.privacyPolicy", defaultValue: "Gizlilik Politikası")
    public static let settingsTerms = localized("settings.terms", defaultValue: "Kullanım Şartları")
    public static let settingsSupport = localized("settings.support", defaultValue: "Destek ve İletişim")
    public static let settingsPrivacySection = localized("settings.privacySection", defaultValue: "Gizlilik")
    public static let settingsPrivacyPreferences = localized("settings.privacyPreferences", defaultValue: "Gizlilik tercihleri")

    public static let premiumTitle = localized("premium.title", defaultValue: "Ekitaplığım Premium")
    public static let premiumDescription = localized("premium.description", defaultValue: "Premium üyelik, sunucu tarafından belirlenen daha yüksek veya sınırsız okuma ve indirme hakları sağlar.")
    public static let premiumPlans = localized("premium.plans", defaultValue: "Abonelik Planları")
    public static let premiumLoading = localized("premium.loading", defaultValue: "Apple ürünleri yükleniyor")
    public static let premiumPurchasing = localized("premium.purchasing", defaultValue: "Satın alma doğrulanıyor")
    public static let premiumPurchased = localized("premium.purchased", defaultValue: "Premium üyeliğiniz etkinleştirildi.")
    public static let premiumRestored = localized("premium.restored", defaultValue: "Satın almanız geri yüklendi ve doğrulandı.")
    public static let premiumPending = localized("premium.pending", defaultValue: "Satın alma Apple onayı bekliyor.")
    public static let premiumRestore = localized("premium.restore", defaultValue: "Satın almaları geri yükle")
    public static let premiumManageSubscriptions = localized("premium.manageSubscriptions", defaultValue: "Apple aboneliklerini yönet")
    public static let premiumLoginRequired = localized("premium.loginRequired", defaultValue: "Satın alma için Ekitaplığım hesabınıza giriş yapın.")
    public static let premiumBenefitReading = localized("premium.benefit.reading", defaultValue: "Premium kitaplara ve geniş okuma haklarına erişim")
    public static let premiumBenefitDownloads = localized("premium.benefit.downloads", defaultValue: "Daha yüksek veya sınırsız indirme hakları")
    public static let premiumMembershipStatus = localized("premium.membershipStatus", defaultValue: "Üyelik Durumu")
    public static let premiumPlan = localized("premium.plan", defaultValue: "Plan")
    public static let premiumMonthlyPeriod = localized("premium.period.monthly", defaultValue: "Her ay otomatik yenilenir")
    public static let premiumYearlyPeriod = localized("premium.period.yearly", defaultValue: "Her yıl otomatik yenilenir")
    public static let premiumStatusActive = localized("premium.status.active", defaultValue: "Premium aboneliğiniz aktif")
    public static let premiumStatusCancelled = localized("premium.status.cancelled", defaultValue: "Otomatik yenileme kapalı; erişiminiz dönem sonuna kadar aktif")
    public static let premiumStatusGracePeriod = localized("premium.status.gracePeriod", defaultValue: "Ödeme ek süresi içinde; Premium erişiminiz devam ediyor")
    public static let premiumStatusBillingRetry = localized("premium.status.billingRetry", defaultValue: "Apple ödemeyi yeniden deniyor")
    public static let premiumStatusExpired = localized("premium.status.expired", defaultValue: "Premium aboneliğiniz sona erdi")
    public static let premiumStatusRevoked = localized("premium.status.revoked", defaultValue: "Premium erişiminiz Apple tarafından geri alındı")
    public static func premiumValidUntil(_ date: String) -> String {
        String(format: localized("premium.validUntil", defaultValue: "%@ tarihine kadar geçerli"), date)
    }
    public static let premiumCancellationNote = localized("premium.cancellationNote", defaultValue: "İptal Apple abonelik yönetim ekranından yapılır. İptal, mevcut dönemin sonuna kadar erişiminizi kapatmaz.")
    public static let premiumRenewalDisclosure = localized("premium.renewalDisclosure", defaultValue: "Ödeme Apple ID hesabınızdan alınır. Abonelik, geçerli dönemin bitiminden en az 24 saat önce iptal edilmezse otomatik yenilenir. Fiyat ve dönem Apple satın alma ekranında gösterilir; aboneliği App Store hesap ayarlarından yönetebilir veya iptal edebilirsiniz.")
    public static let premiumProductsFailed = localized("premium.error.products", defaultValue: "Apple ürün bilgileri alınamadı.")
    public static let premiumProductMissing = localized("premium.error.productMissing", defaultValue: "Seçilen abonelik Apple mağazasında bulunamadı.")
    public static let premiumPurchaseFailed = localized("premium.error.purchase", defaultValue: "Satın alma tamamlanamadı.")
    public static let premiumVerificationFailed = localized("premium.error.verification", defaultValue: "Satın alma güvenli biçimde doğrulanamadı.")
    public static let premiumNothingToRestore = localized("premium.error.nothingToRestore", defaultValue: "Geri yüklenecek etkin bir premium abonelik bulunamadı.")
    public static let premiumRestoreFailed = localized("premium.error.restore", defaultValue: "Satın almalar geri yüklenemedi veya sunucuda doğrulanamadı.")

    public static let catalogTitle = localized("catalog.title", defaultValue: "Kitaplar")
    public static let catalogHeroTitle = localized("catalog.hero.title", defaultValue: "Kataloğu Keşfet")
    public static let catalogEyebrow = localized("catalog.eyebrow", defaultValue: "KATALOG")
    public static let catalogHeroBooksCaption = localized("catalog.hero.booksCaption", defaultValue: "kitap")
    public static func catalogHeroBookCount(_ formattedCount: String) -> String {
        String(format: localized("catalog.hero.bookCount", defaultValue: "%@ kitap"), formattedCount)
    }
    public static func catalogHeroSubtitle(category: String, page: Int, lastPage: Int) -> String {
        String(format: localized("catalog.hero.subtitle", defaultValue: "%1$@ · Sayfa %2$d / %3$d"), category, page, lastPage)
    }
    public static let catalogStatTotal = localized("catalog.stat.total", defaultValue: "Toplam")
    public static let catalogStatLoaded = localized("catalog.stat.loaded", defaultValue: "Yüklenen")
    public static let catalogStatCatalogPage = localized("catalog.stat.catalogPage", defaultValue: "Katalog sayfası")
    public static func catalogPagePosition(_ current: Int, _ last: Int) -> String {
        String(format: localized("catalog.page.position", defaultValue: "%1$d / %2$d"), current, last)
    }
    public static func catalogCategoryChip(_ title: String, countLabel: String) -> String {
        String(format: localized("catalog.chip.withCount", defaultValue: "%1$@  %2$@"), title, countLabel)
    }
    public static func catalogBookPageCount(_ count: Int) -> String {
        String(format: localized("catalog.book.pageCount", defaultValue: "%d syf"), count)
    }
    public static let catalogLoading = localized("catalog.loading", defaultValue: "Kitaplar yükleniyor")
    public static let catalogUnavailableTitle = localized("catalog.unavailableTitle", defaultValue: "Katalog açılamadı")
    public static let catalogEmptyTitle = localized("catalog.emptyTitle", defaultValue: "Kitap bulunamadı")
    public static let catalogEmptyDescription = localized("catalog.emptyDescription", defaultValue: "Aramanızı değiştirip tekrar deneyin.")
    public static let catalogSearchPrompt = localized("catalog.searchPrompt", defaultValue: "Kitap, yazar veya ISBN")
    public static let catalogLoadFailed = localized("catalog.loadFailed", defaultValue: "Kitaplar alınamadı. Bağlantınızı kontrol edip tekrar deneyin.")
    public static let catalogFiltersTitle = localized("catalog.filters.title", defaultValue: "Filtreler")
    public static let catalogFilterDetails = localized("catalog.filters.details", defaultValue: "Kitap Bilgileri")
    public static let catalogFilterAuthor = localized("catalog.filters.author", defaultValue: "Yazar")
    public static let catalogFilterPublisher = localized("catalog.filters.publisher", defaultValue: "Yayınevi")
    public static let catalogFilterISBN = localized("catalog.filters.isbn", defaultValue: "ISBN")
    public static let catalogFilterPremium = localized("catalog.filters.premium", defaultValue: "Yalnızca premium kitaplar")
    public static let catalogFilterCategory = localized("catalog.filters.category", defaultValue: "Kategori")
    public static let catalogFilterAllChip = localized("catalog.filters.allChip", defaultValue: "Hepsi")
    public static let catalogFilterAllCategories = localized("catalog.filters.allCategories", defaultValue: "Tüm kategoriler")
    public static let catalogFilterOrder = localized("catalog.filters.order", defaultValue: "Sıralama")
    public static let catalogOrderLatest = localized("catalog.order.latest", defaultValue: "En yeni")
    public static let catalogOrderPopular = localized("catalog.order.popular", defaultValue: "Popüler")
    public static let catalogOrderRated = localized("catalog.order.rated", defaultValue: "Puan")
    public static let catalogFilterReset = localized("catalog.filters.reset", defaultValue: "Sıfırla")
    public static let catalogFilterApply = localized("catalog.filters.apply", defaultValue: "Uygula")
    public static let catalogLoadMore = localized("catalog.loadMore", defaultValue: "Daha fazla yükle")
    public static let catalogLoadingMore = localized("catalog.loadingMore", defaultValue: "Yükleniyor")
    public static let catalogShowGrid = localized("catalog.display.grid", defaultValue: "Izgara görünümüne geç")
    public static let catalogShowList = localized("catalog.display.list", defaultValue: "Liste görünümüne geç")

    public static let libraryTitle = localized("library.title", defaultValue: "Kitaplığım")
    public static let libraryLoading = localized("library.loading", defaultValue: "Kitaplık yükleniyor")
    public static let libraryUnavailableTitle = localized("library.unavailableTitle", defaultValue: "Kitaplık alınamadı")
    public static let libraryEmptyTitle = localized("library.emptyTitle", defaultValue: "Bu rafta henüz kitap yok.")
    public static let libraryEmptyDescription = localized("library.emptyDescription", defaultValue: "Kitap eklediğinde burada görünecek.")
    public static let librarySelectedShelfLabel = localized("library.selectedShelfLabel", defaultValue: "Seçili raf")
    public static func librarySelectedShelfBooks(_ count: Int) -> String {
        String(format: localized("library.selectedShelfBooks", defaultValue: "%d kitap bu rafta"), count)
    }
    public static func libraryTabBookCount(_ count: Int) -> String {
        String(format: localized("library.tabBookCount", defaultValue: "%d kitap"), count)
    }
    public static let forumMessageEmpty = localized("forumMessage.empty", defaultValue: "Mesaj içeriği görüntülenemedi.")
    public static let libraryLoadFailed = localized("library.loadFailed", defaultValue: "Kitaplık bilgileri alınamadı.")
    public static let libraryDownloadsLabel = localized("library.downloadsLabel", defaultValue: "İndirilenler")
    public static let libraryShelfPicker = localized("library.shelfPicker", defaultValue: "Raf")
    public static let libraryShelfAdd = localized("library.shelf.add", defaultValue: "Rafa Ekle")
    public static let libraryShelfLater = localized("library.shelf.later", defaultValue: "Daha sonra oku")
    public static let libraryShelfLaterShort = localized("library.shelf.laterShort", defaultValue: "Daha sonra")
    public static let libraryShelfRemove = localized("library.shelf.remove", defaultValue: "Raftan Kaldır")
    public static let libraryShelfAll = localized("library.shelf.all", defaultValue: "Tümü")
    public static let libraryShelfReading = localized("library.shelf.reading", defaultValue: "Okuyorum")
    public static let libraryShelfFinished = localized("library.shelf.finished", defaultValue: "Okudum")
    public static let libraryShelfFavorites = localized("library.shelf.favorites", defaultValue: "Favoriler")
    public static let libraryShelfDownloads = localized("library.shelf.downloads", defaultValue: "İndirilen")
    public static let libraryReadingProgressLabel = localized("library.readingProgressLabel", defaultValue: "Okuma ilerlemesi")
    public static let libraryOpenBookDetail = localized("library.openBookDetail", defaultValue: "Kitap detayını aç")
    public static func libraryCoverAccessibility(_ title: String) -> String {
        String(format: localized("library.coverAccessibility", defaultValue: "%@ kapağı"), title)
    }
    public static let libraryFavoriteBadge = localized("library.favoriteBadge", defaultValue: "Favori")
    public static let libraryDownloadedBadge = localized("library.downloadedBadge", defaultValue: "İndirildi")
    public static let libraryDownloadOfflineReady = localized("library.downloadOfflineReady", defaultValue: "Cihazda çevrimdışı okumaya hazır")
    public static let libraryDownloadServerHistory = localized("library.downloadServerHistory", defaultValue: "Daha önce indirildi")
    public static let libraryMetaFinished = localized("library.meta.finished", defaultValue: "Tamamlandı")
    public static let libraryMetaWantToRead = localized("library.meta.wantToRead", defaultValue: "Daha sonra oku")
    public static let libraryMetaFavorite = localized("library.meta.favorite", defaultValue: "Favorilerde")
    public static let libraryMetaDownloaded = localized("library.meta.downloaded", defaultValue: "İndirildi")
    public static let libraryMetaContinue = localized("library.meta.continue", defaultValue: "Devam et")
    public static let libraryAuthorMissing = localized("library.authorMissing", defaultValue: "Yazar bilgisi yok")
    public static func libraryMetaLastPage(_ page: Int) -> String {
        String(format: localized("library.meta.lastPage", defaultValue: "Kaldığın yer: %d. sayfa"), page)
    }
    public static let libraryHeaderSubtitle = localized("library.headerSubtitle", defaultValue: "Okuma yolculuğunu raflarına göre yönet.")
    public static func librarySelectedShelf(_ shelf: String, _ count: Int) -> String {
        String(format: localized("library.selectedShelf", defaultValue: "Seçili raf: %1$@ · %2$d kitap"), shelf, count)
    }
    public static let libraryBookCountLabel = localized("library.bookCountLabel", defaultValue: "kitap")

    public static let downloadsTitle = localized("downloads.title", defaultValue: "İndirilenler")
    public static let downloadsEmptyTitle = localized("downloads.emptyTitle", defaultValue: "İndirilen kitap yok")
    public static let downloadsEmptyDescription = localized("downloads.emptyDescription", defaultValue: "Çevrimdışı indirdiğiniz kitaplar burada görünür.")
    public static let downloadsNotDownloaded = localized("downloads.notDownloaded", defaultValue: "İndirilmedi")
    public static let downloadsQueued = localized("downloads.queued", defaultValue: "Sırada")

    public static func commonBookNumber(_ bookID: String) -> String {
        String(format: localized("common.bookNumber", defaultValue: "Kitap #%@"), bookID)
    }

    public static func commonPercent(_ percent: Int) -> String {
        String(format: localized("common.percent", defaultValue: "%%%d"), percent)
    }

    public static func downloadsDownloading(_ percent: Int) -> String {
        String(format: localized("downloads.downloading", defaultValue: "İndiriliyor %d%%"), percent)
    }

    public static func downloadsReady(_ fileName: String) -> String {
        String(format: localized("downloads.ready", defaultValue: "Hazır: %@"), fileName)
    }

    public static let communityTitle = localized("community.title", defaultValue: "Topluluk")
    public static let communityHeroSubtitle = localized("community.hero.subtitle", defaultValue: "Forumlar, üyeler ve güvenlik araçları")
    public static let communityLoading = localized("community.loading", defaultValue: "Forumlar yükleniyor")
    public static let communityUnavailableTitle = localized("community.unavailableTitle", defaultValue: "Forumlar alınamadı")
    public static let communityForumsSection = localized("community.forumsSection", defaultValue: "Forumlar")
    public static let communitySafetySection = localized("community.safetySection", defaultValue: "Güvenlik")
    public static let communitySafetyTitle = localized("community.safetyTitle", defaultValue: "Topluluk Güvenliği")
    public static let communitySafetyCommitmentTitle = localized("community.safetyCommitmentTitle", defaultValue: "Güvenlik taahhüdümüz")
    public static let communitySafetySLA = localized("community.safetySLA", defaultValue: "Bildirilen içerikler en geç 24 saat içinde moderasyon incelemesine alınır.")
    public static let communitySafetyRulesSummary = localized("community.safetyRulesSummary", defaultValue: "Nefret söylemi, taciz, zorbalık, cinsel içerik, şiddet tehdidi, spam ve kişisel bilgilerin izinsiz paylaşımı yasaktır.")
    public static let communitySafetyControlsTitle = localized("community.safetyControlsTitle", defaultValue: "Güvenlik denetimleri")
    public static let communitySafetyContactSupport = localized("community.safetyContactSupport", defaultValue: "Destek ekibiyle iletişime geç")
    public static let communityBlockUser = localized("community.blockUser", defaultValue: "Kullanıcı engelle")
    public static let communityBlockedUsers = localized("community.blockedUsers", defaultValue: "Engellenen kullanıcılar")
    public static let communityForumsLoadFailed = localized("community.forumsLoadFailed", defaultValue: "Forum listesi alınamadı.")

    public static let blockMemberTitle = localized("blockMember.title", defaultValue: "Kullanıcı engelle")
    public static let blockMemberUserIdPlaceholder = localized("blockMember.userIdPlaceholder", defaultValue: "Kullanıcı ID")
    public static let blockMemberFooter = localized("blockMember.footer", defaultValue: "Engellenen kullanıcının içerikleri uygun ekranlarda gizlenir. Kötüye kullanım durumunda ayrıca içerik raporu gönderin.")
    public static let blockMemberSubmit = localized("blockMember.submit", defaultValue: "Kullanıcıyı engelle")
    public static let blockMemberSuccess = localized("blockMember.success", defaultValue: "Kullanıcı engellendi.")
    public static let blockMemberFailure = localized("blockMember.failure", defaultValue: "Kullanıcı engellenemedi.")

    public static let blockedMembersTitle = localized("blockedMembers.title", defaultValue: "Engellenenler")
    public static let blockedMembersLoading = localized("blockedMembers.loading", defaultValue: "Engellenenler yükleniyor")
    public static let blockedMembersUnavailableTitle = localized("blockedMembers.unavailableTitle", defaultValue: "Liste alınamadı")
    public static let blockedMembersEmptyTitle = localized("blockedMembers.emptyTitle", defaultValue: "Engellenen kullanıcı yok")
    public static let blockedMembersRemove = localized("blockedMembers.remove", defaultValue: "Kaldır")
    public static let blockedMembersLoadFailed = localized("blockedMembers.loadFailed", defaultValue: "Engellenen kullanıcılar alınamadı.")

    public static let forumThreadsLoading = localized("forumThreads.loading", defaultValue: "Konular yükleniyor")
    public static let forumThreadsUnavailableTitle = localized("forumThreads.unavailableTitle", defaultValue: "Konular alınamadı")
    public static let forumThreadsEmptyTitle = localized("forumThreads.emptyTitle", defaultValue: "Bu forumda henüz konu yok.")
    public static let forumThreadsEmptyDescription = localized("forumThreads.emptyDescription", defaultValue: "İlk konuyu açmak için sağ üstteki + düğmesine dokunun.")
    public static let forumThreadsInvalidForum = localized("forumThreads.invalidForum", defaultValue: "Forum kimliği geçersiz.")
    public static let forumThreadsLoadFailed = localized("forumThreads.loadFailed", defaultValue: "Forum konuları alınamadı.")
    public static let forumThreadsCreate = localized("forumThreads.create", defaultValue: "Konu Aç")
    public static let forumThreadsCreateDialogTitle = localized("forumThreads.createDialogTitle", defaultValue: "Yeni konu aç")
    public static let forumThreadsCreateAccessibility = localized("forumThreads.createAccessibility", defaultValue: "Yeni konu")
    public static let forumThreadsLoadMore = localized("forumThreads.loadMore", defaultValue: "Daha fazla konu yükle")
    public static let forumThreadsLoadMoreLoading = localized("forumThreads.loadMoreLoading", defaultValue: "Yükleniyor...")
    public static let forumThreadsCreateSubmit = localized("forumThreads.createSubmit", defaultValue: "Oluştur")
    public static let forumThreadsCreateTitleSection = localized("forumThreads.createTitleSection", defaultValue: "Konu başlığı")
    public static let forumThreadsCreateTitlePlaceholder = localized("forumThreads.createTitlePlaceholder", defaultValue: "Konu başlığı")
    public static let forumThreadsCreateMessageSection = localized("forumThreads.createMessageSection", defaultValue: "İlk mesaj")
    public static let forumThreadsCreateFailedTitle = localized("forumThreads.createFailedTitle", defaultValue: "Konu açılamadı")
    public static let forumThreadsCreateFailedMessage = localized("forumThreads.createFailedMessage", defaultValue: "Konu oluşturulurken bir hata oluştu.")
    public static let forumThreadsCreateSuccess = localized("forumThreads.createSuccess", defaultValue: "Konu oluşturuldu.")
    public static let forumThreadsLoginRequiredMessage = localized("forumThreads.loginRequiredMessage", defaultValue: "Konu açmak için giriş yapmalısınız.")
    public static let forumThreadsCommunitySubtitle = localized("forumThreads.communitySubtitle", defaultValue: "Ekitaplığım topluluk forumu")
    public static let forumThreadsHeroMetricLabel = localized("forumThreads.heroMetricLabel", defaultValue: "Konu")
    public static let forumThreadsHeroHint = localized("forumThreads.heroHint", defaultValue: "Toplulukla paylaşmak istediğiniz konuları buradan açabilirsiniz.")
    public static let forumThreadsSticky = localized("forumThreads.sticky", defaultValue: "Sabitlenmiş konu")

    public static func forumThreadsHeroCount(_ count: Int) -> String {
        String(format: localized("forumThreads.heroCount", defaultValue: "%d Konu"), count)
    }

    public static func forumThreadsCollapsedCount(_ count: Int) -> String {
        String(format: localized("forumThreads.collapsedCount", defaultValue: "%d konu"), count)
    }

    public static func forumThreadsMeta(username: String, replyCount: Int, viewCount: Int) -> String {
        String(format: localized("forumThreads.meta", defaultValue: "%@ • %d cevap • %d görüntüleme"), username, replyCount, viewCount)
    }

    public static func forumThreadDetailMeta(_ replies: Int) -> String {
        String(format: localized("forumThread.detailMeta", defaultValue: "%d mesaj · Ekitaplığım Forum"), replies)
    }

    public static func forumThreadCollapsedMessageCount(_ count: Int) -> String {
        String(format: localized("forumThread.collapsedMessageCount", defaultValue: "%d mesaj"), count)
    }

    public static let forumDefaultUsername = localized("forum.defaultUsername", defaultValue: "Ekitaplığım")
    public static let forumThreadEmptyPosts = localized("forumThread.emptyPosts", defaultValue: "Bu konuda mesaj bulunamadı.")
    public static let forumThreadGuestLoginShort = localized("forumThread.guestLoginShort", defaultValue: "Giriş")

    public static let forumThreadLoading = localized("forumThread.loading", defaultValue: "Mesajlar yükleniyor")
    public static let forumThreadReportPost = localized("forumThread.reportPost", defaultValue: "Mesajı raporla")
    public static let ugcSafetyActions = localized("ugc.safetyActions", defaultValue: "Güvenlik işlemleri")
    public static let ugcReportContent = localized("ugc.reportContent", defaultValue: "İçeriği bildir")
    public static let ugcBlockAndReport = localized("ugc.blockAndReport", defaultValue: "Kullanıcıyı engelle ve bildir")
    public static let ugcBlockAndReportDescription = localized("ugc.blockAndReportDescription", defaultValue: "İçerik moderasyona gönderilir ve bu kullanıcının içerikleri hesabınızdan hemen gizlenir.")
    public static let ugcReasonSpam = localized("ugc.reason.spam", defaultValue: "Spam")
    public static let ugcReasonHarassment = localized("ugc.reason.harassment", defaultValue: "Taciz veya zorbalık")
    public static let ugcReasonHate = localized("ugc.reason.hate", defaultValue: "Nefret söylemi")
    public static let ugcReasonSexual = localized("ugc.reason.sexual", defaultValue: "Cinsel içerik")
    public static let ugcReasonViolence = localized("ugc.reason.violence", defaultValue: "Şiddet veya tehdit")
    public static let ugcReasonPrivacy = localized("ugc.reason.privacy", defaultValue: "Kişisel bilgi ihlali")
    public static let ugcReasonCopyright = localized("ugc.reason.copyright", defaultValue: "Telif hakkı")
    public static let ugcReasonOther = localized("ugc.reason.other", defaultValue: "Diğer")
    public static let forumThreadReportAction = localized("forumThread.reportAction", defaultValue: "Raporla")
    public static let forumThreadReplyPlaceholder = localized("forumThread.replyPlaceholder", defaultValue: "Cevabınızı yazın...")
    public static let forumThreadPostImage = localized("forumThread.postImage", defaultValue: "Forum görseli")
    public static let forumThreadBlockUser = localized("forumThread.blockUser", defaultValue: "Kullanıcıyı engelle")
    public static let forumThreadReplySection = localized("forumThread.replySection", defaultValue: "Cevap yaz")
    public static let forumThreadReplyTextLabel = localized("forumThread.replyTextLabel", defaultValue: "Cevap metni")
    public static let forumThreadSubmitReply = localized("forumThread.submitReply", defaultValue: "Cevapla")
    public static let forumThreadInvalidThread = localized("forumThread.invalidThread", defaultValue: "Konu kimliği geçersiz.")
    public static let forumThreadLoadFailed = localized("forumThread.loadFailed", defaultValue: "Konu mesajları alınamadı.")
    public static let forumThreadReplyPublished = localized("forumThread.replyPublished", defaultValue: "Cevabınız yayınlandı.")
    public static let forumThreadReplyFailed = localized("forumThread.replyFailed", defaultValue: "Cevap gönderilemedi.")
    public static let forumThreadGuestReplyTitle = localized("forumThread.guestReplyTitle", defaultValue: "Cevap yazmak için kayıt olun")
    public static let forumThreadGuestReplyMessage = localized(
        "forumThread.guestReplyMessage",
        defaultValue: "Forum sohbetine katılmak için giriş yapın veya ücretsiz hesap oluşturun."
    )
    public static let forumThreadReplyLockedTitle = localized("forumThread.replyLockedTitle", defaultValue: "Bu konuya cevap veremezsiniz")
    public static let forumThreadReplyLockedMessage = localized("forumThread.replyLockedMessage", defaultValue: "Forum izinleriniz bu konuya yazmanıza izin vermiyor.")
    public static let forumThreadReplyPermissionHint = localized(
        "forumThread.replyPermissionHint",
        defaultValue: "Cevap yetkiniz gönderim sırasında kontrol edilir."
    )

    public static let notificationsTitle = localized("notifications.title", defaultValue: "Bildirimler")
    public static let notificationsLoading = localized("notifications.loading", defaultValue: "Bildirimler yükleniyor")
    public static let notificationsUnavailableTitle = localized("notifications.unavailableTitle", defaultValue: "Bildirimler alınamadı")
    public static let notificationsEmptyTitle = localized("notifications.emptyTitle", defaultValue: "Bildirim yok")
    public static let notificationsUnread = localized("notifications.unread", defaultValue: "Okunmamış")
    public static let notificationsReadSyncFailed = localized("notifications.readSyncFailed", defaultValue: "Okundu bilgisi sunucuyla eşitlenemedi. Uygulama yeniden açıldığında tekrar denenecek.")
    public static let notificationsNew = localized("notifications.new", defaultValue: "Yeni")
    public static let notificationsMarkAllRead = localized("notifications.markAllRead", defaultValue: "Tümünü oku")
    public static let notificationsNoDestination = localized("notifications.noDestination", defaultValue: "Bu bildirim için açılabilecek bir içerik bulunamadı.")
    public static let notificationsLoadFailed = localized("notifications.loadFailed", defaultValue: "Bildirimler alınamadı.")

    public static let profileTitle = localized("profile.title", defaultValue: "Profilim")
    public static let profileLoading = localized("profile.loading", defaultValue: "Profil yükleniyor")
    public static let profileUnavailableTitle = localized("profile.unavailableTitle", defaultValue: "Profil alınamadı")
    public static let profileEmptyTitle = localized("profile.emptyTitle", defaultValue: "Profil yok")
    public static let profileStatsSection = localized("profile.statsSection", defaultValue: "İstatistikler")
    public static let profileMessageCount = localized("profile.messageCount", defaultValue: "Mesaj")
    public static let profileReactionScore = localized("profile.reactionScore", defaultValue: "Tepki")
    public static let profileRegisterDate = localized("profile.registerDate", defaultValue: "Kayıt tarihi")
    public static let profilePermissionsSection = localized("profile.permissionsSection", defaultValue: "Yetki")
    public static let profileStaff = localized("profile.staff", defaultValue: "Personel")
    public static let profileCanEdit = localized("profile.canEdit", defaultValue: "Düzenleme")
    public static let profileYes = localized("profile.yes", defaultValue: "Evet")
    public static let profileNo = localized("profile.no", defaultValue: "Hayır")
    public static let profileOpen = localized("profile.open", defaultValue: "Açık")
    public static let profileClosed = localized("profile.closed", defaultValue: "Kapalı")
    public static let profileLoadFailed = localized("profile.loadFailed", defaultValue: "Profil bilgileri alınamadı.")
    public static let profileEditTitle = localized("profile.edit.title", defaultValue: "Profili Düzenle")
    public static let profileEditGeneralSection = localized("profile.edit.generalSection", defaultValue: "Genel Bilgiler")
    public static let profileEditAbout = localized("profile.edit.about", defaultValue: "Hakkında")
    public static let profileEditLocation = localized("profile.edit.location", defaultValue: "Konum")
    public static let profileEditWebsite = localized("profile.edit.website", defaultValue: "Web sitesi")
    public static let profileEditActivityVisible = localized("profile.edit.activityVisible", defaultValue: "Çevrimiçi durumumu göster")
    public static let profileEditSave = localized("profile.edit.save", defaultValue: "Kaydet")
    public static let profileEditSaving = localized("profile.edit.saving", defaultValue: "Kaydediliyor")
    public static let profileEditSaveFailed = localized("profile.edit.saveFailed", defaultValue: "Profil değişiklikleri kaydedilemedi.")

    private static func localized(_ key: String, defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}
