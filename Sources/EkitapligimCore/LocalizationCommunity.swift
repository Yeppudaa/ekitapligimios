import Foundation

/// Turkish strings for the navigation shell, profile, Kitap Gündemi, Okur Sohbeti and Canlı Aktivite screens.
public extension L10n {

    // MARK: - Ortak

    static var commonLoading: String { tr("common.loading", "Yükleniyor") }
    static var commonLoadMoreItems: String { tr("common.loadMoreItems", "Daha fazla göster") }
    static var commonRefresh: String { tr("common.refresh", "Yenile") }
    static var commonBack: String { tr("common.back", "Geri") }
    static var commonAll: String { tr("common.all", "Tümü") }
    static var commonEdit: String { tr("common.edit", "Düzenle") }
    static var commonDelete: String { tr("common.delete", "Sil") }
    static var commonDeleting: String { tr("common.deleting", "Siliniyor…") }
    static var commonSave: String { tr("common.save", "Kaydet") }
    static var commonSaving: String { tr("common.saving", "Kaydediliyor…") }
    static var commonDismiss: String { tr("common.dismiss", "Vazgeç") }
    static var commonLogin: String { tr("common.login", "Giriş yap") }
    static var commonSelect: String { tr("common.select", "Seç") }
    static var commonRetryAgain: String { tr("common.retryAgain", "Yeniden dene") }

    static var timeJustNow: String { tr("time.justNow", "Az önce") }
    static func timeMinutesAgo(_ value: Int) -> String { String(format: tr("time.minutesAgo", "%d dk önce"), value) }
    static func timeHoursAgo(_ value: Int) -> String { String(format: tr("time.hoursAgo", "%d sa önce"), value) }
    static func timeDaysAgo(_ value: Int) -> String { String(format: tr("time.daysAgo", "%d gün önce"), value) }
    static func readingMinutesShort(_ value: Int) -> String { String(format: tr("reading.minutesShort", "%d dk"), value) }
    static func readingHoursShort(_ value: Int) -> String { String(format: tr("reading.hoursShort", "%d sa"), value) }
    static func unreadCountAccessibility(_ value: Int) -> String {
        String(format: tr("accessibility.unreadCount", "%d okunmamış"), value)
    }
    static func readingGoalProgressAccessibility(_ percent: Int) -> String {
        String(format: tr("accessibility.readingGoalProgress", "Günlük hedefin yüzde %d tamamlandı"), percent)
    }

    // MARK: - Alt sekmeler

    static var tabAuthors: String { tr("tab.authors", "Yazarlar") }
    static var tabRequests: String { tr("tab.requests", "İstekler") }
    static var tabForum: String { tr("tab.forum", "Forum") }
    static var tabProfile: String { tr("tab.profile", "Profilim") }
    static var tabCatalogShort: String { tr("tab.catalogShort", "Katalog") }

    // MARK: - Yan menü

    static var menuBrandTitle: String { tr("menu.brandTitle", "E-Kitaplığım") }
    static var menuClose: String { tr("menu.close", "Menüyü kapat") }
    static var menuAccountSection: String { tr("menu.accountSection", "Hesabım") }
    static var menuMembershipSection: String { tr("menu.membershipSection", "Üyelik") }

    static var menuHome: String { tr("menu.home", "Ana sayfa") }
    static var menuHomeSubtitle: String { tr("menu.homeSubtitle", "Öne çıkan kitaplar ve keşif alanı") }
    static var menuBooks: String { tr("menu.books", "Kitaplar") }
    static var menuBooksSubtitle: String { tr("menu.booksSubtitle", "Tüm e-kitap kataloğu") }
    static var menuBookAgenda: String { tr("menu.bookAgenda", "Kitap Gündemi") }
    static var menuBookAgendaSubtitle: String { tr("menu.bookAgendaSubtitle", "Notlar, alıntılar ve okuma güncellemeleri") }
    static var menuChat: String { tr("menu.chat", "Okur Sohbeti") }
    static var menuChatSubtitle: String { tr("menu.chatSubtitle", "Canlı odalar ve okur mesajları") }
    static var menuLiveActivity: String { tr("menu.liveActivity", "Canlı Akış") }
    static var menuLiveActivitySubtitle: String { tr("menu.liveActivitySubtitle", "Topluluktaki son kitap hareketleri") }
    static var menuRequests: String { tr("menu.requests", "Kitap İstekleri") }
    static var menuAuthors: String { tr("menu.authors", "Yazarlar") }
    static var menuPublishers: String { tr("menu.publishers", "Yayınevleri") }
    static var menuForum: String { tr("menu.forum", "Forum") }
    static var menuForumSubtitle: String { tr("menu.forumSubtitle", "Topluluk konuları ve sohbet") }
    static var menuMembers: String { tr("menu.members", "Üyeler") }
    static var menuMembersSubtitle: String { tr("menu.membersSubtitle", "Okurlar ve topluluk profilleri") }
    static var menuMessages: String { tr("menu.messages", "Mesajlar") }
    static var menuMessagesSubtitle: String { tr("menu.messagesSubtitle", "Özel konuşmalar ve yanıtlar") }
    static var menuPremiumSubtitle: String { tr("menu.premiumSubtitle", "Ayrıcalıkları aç • VIP arşiv ve daha fazlası") }
    static var menuProfile: String { tr("menu.profile", "Profilim") }
    static var menuProfileSubtitle: String { tr("menu.profileSubtitle", "Hesap ve okuma bilgileri") }
    static var menuNotifications: String { tr("menu.notifications", "Bildirimler") }
    static var menuNotificationsSubtitle: String { tr("menu.notificationsSubtitle", "Forum ve kitap bildirimleri") }
    static var menuLibrary: String { tr("menu.library", "Kütüphanem") }
    static var menuLibrarySubtitle: String { tr("menu.librarySubtitle", "Kaydedilen ve okunan kitaplar") }
    static var menuLoginSubtitle: String { tr("menu.loginSubtitle", "Hesabına güvenli giriş yap") }
    static var menuRegister: String { tr("menu.register", "Kayıt ol") }
    static var menuRegisterSubtitle: String { tr("menu.registerSubtitle", "E-Kitaplığım hesabı oluştur") }

    // MARK: - Profilim

    static var profileScreenTitle: String { tr("profile.screen.title", "Profilim") }
    static var profileMemberFallback: String { tr("profile.memberFallback", "E-Kitaplığım üyesi") }
    static var profileRoleAdmin: String { tr("profile.role.admin", "Yönetici") }
    static var profileRoleStaff: String { tr("profile.role.staff", "Yetkili") }
    static var profileRolePremium: String { tr("profile.role.premium", "Premium") }
    static var profileRolePremiumMember: String { tr("profile.role.premiumMember", "Premium Üye") }
    static var profileVerifiedAccessibility: String { tr("profile.verifiedAccessibility", "Doğrulanmış") }
    static func profileJoinedOn(_ date: String) -> String { String(format: tr("profile.joinedOn", "Katılım %@"), date) }
    static func profileLastSeen(_ date: String) -> String { String(format: tr("profile.lastSeen", "Son görülme %@"), date) }

    static var profileStatMessages: String { tr("profile.stat.messages", "Mesajlar") }
    static var profileStatReactions: String { tr("profile.stat.reactions", "Tepkime Puanı") }
    static var profileStatPoints: String { tr("profile.stat.points", "Puan") }
    static var profileStatReading: String { tr("profile.stat.reading", "Okuyorum") }
    static var profileStatRead: String { tr("profile.stat.read", "Okudum") }
    static var profileStatListed: String { tr("profile.stat.listed", "Listemde") }

    static var profileTabProfile: String { tr("profile.tab.profile", "Profil") }
    static var profileTabLibrary: String { tr("profile.tab.library", "Kütüphane") }
    static var profileTabPosts: String { tr("profile.tab.posts", "Gönderiler") }
    static var profileTabActivity: String { tr("profile.tab.activity", "Son Aktivite") }
    static var profileTabAbout: String { tr("profile.tab.about", "Hakkında") }
    static var profileTabBadges: String { tr("profile.tab.badges", "Rozetler") }

    static var profileSummaryReading: String { tr("profile.summary.reading", "Kitap Okuyorum") }
    static var profileSummaryRead: String { tr("profile.summary.read", "Kitap Okudum") }
    static var profileSummaryListed: String { tr("profile.summary.listed", "Kitap Listemde") }

    static var readingGoalTitle: String { tr("readingGoal.title", "Günlük okuma hedefin") }
    static var readingGoalCompletedTitle: String { tr("readingGoal.completedTitle", "Günlük hedef tamamlandı") }
    static var readingGoalCompletedSubtitle: String {
        tr("readingGoal.completedSubtitle", "Bugünkü hedefini tamamladın. Harika gidiyorsun.")
    }
    static func readingGoalSubtitle(done: Int, goal: Int, remaining: Int) -> String {
        String(format: tr("readingGoal.subtitle", "%1$d / %2$d dakika • %3$d dakika kaldı"), done, goal, remaining)
    }
    static var readingGoalTodayPill: String { tr("readingGoal.todayPill", "Bugün") }
    static var readingGoalDonePill: String { tr("readingGoal.donePill", "Tamamlandı") }
    static var readingGoalTotalPages: String { tr("readingGoal.totalPages", "Toplam okuma") }
    static var readingGoalDuration: String { tr("readingGoal.duration", "Okuma süresi") }
    static var readingGoalStreak: String { tr("readingGoal.streak", "Seri") }
    static func readingGoalPageCount(_ value: Int) -> String { String(format: tr("readingGoal.pageCount", "%d sayfa"), value) }
    static func readingGoalDayCount(_ value: Int) -> String { String(format: tr("readingGoal.dayCount", "%d gün"), value) }

    static var quotaReadTitle: String { tr("quota.readTitle", "Günlük okuma durumunuz") }
    static var quotaDownloadTitle: String { tr("quota.downloadTitle", "Günlük indirme durumunuz") }
    static var quotaAdminTitle: String { tr("quota.adminTitle", "Yönetici erişimin aktif") }
    static var quotaAdminRead: String { tr("quota.adminRead", "Okuma hakkın sınırsız.") }
    static var quotaAdminDownload: String { tr("quota.adminDownload", "İndirme hakkın sınırsız.") }
    static func quotaAdminSubtitle(used: Int, detail: String) -> String {
        String(format: tr("quota.adminSubtitle", "Bugün %1$d kitap. %2$@"), used, detail)
    }
    static func quotaReadSubtitle(used: Int, limit: Int) -> String {
        String(format: tr("quota.readSubtitle", "Bugün %1$d / %2$d kitap okudun"), used, limit)
    }
    static func quotaDownloadSubtitle(used: Int, limit: Int) -> String {
        String(format: tr("quota.downloadSubtitle", "Bugün %1$d / %2$d kitap indirdin"), used, limit)
    }
    static var quotaAdminValue: String { tr("quota.adminValue", "Admin") }
    static var quotaUnlimitedValue: String { tr("quota.unlimitedValue", "Sınırsız") }
    static var quotaActiveCaption: String { tr("quota.activeCaption", "Aktif") }
    static var quotaRemainingCaption: String { tr("quota.remainingCaption", "hak kaldı") }

    static var continueReadingEyebrow: String { tr("continueReading.eyebrow", "OKUMAYA DEVAM ET") }
    static var continueReadingEmptyTitle: String { tr("continueReading.emptyTitle", "Devam edilecek kitap yok") }
    static var continueReadingEmptySubtitle: String {
        tr("continueReading.emptySubtitle", "E-Kitaplığım hesabınızda okuma ilerlemesi bulunamadı")
    }
    static func continueReadingFromPage(_ page: Int) -> String {
        String(format: tr("continueReading.fromPage", "%d. sayfadan devam et"), page)
    }

    static var profileActionLibrary: String { tr("profile.action.library", "Kişisel Kitaplığım") }
    static var profileActionFavorites: String { tr("profile.action.favorites", "Favorilerim") }
    static var profileActionReadLater: String { tr("profile.action.readLater", "Daha sonra oku") }
    static var profileActionReadingNow: String { tr("profile.action.readingNow", "Şu anda okuyorum") }
    static var profileActionFinished: String { tr("profile.action.finished", "Okuduğum kitaplar") }
    static var profileActionDownloads: String { tr("profile.action.downloads", "İndirme geçmişi") }
    static var profileActionBookRequests: String { tr("profile.action.bookRequests", "Kitap istekleri") }
    static var profileActionMyComments: String { tr("profile.action.myComments", "Yorum yaptıklarım") }
    static var profileActionNotifications: String { tr("profile.action.notifications", "Bildirimler") }
    static var profileActionMessages: String { tr("profile.action.messages", "Mesajlar") }
    static var profileActionStats: String { tr("profile.action.stats", "İstatistikler") }

    static var premiumCardActiveTitle: String { tr("premiumCard.activeTitle", "Premium üyeliğin aktif") }
    static var premiumCardUpgradeTitle: String { tr("premiumCard.upgradeTitle", "Okuma deneyimini yükselt") }
    static var premiumCardUpgradeSubtitle: String {
        tr("premiumCard.upgradeSubtitle", "Premium ile günlük 10 okuma ve 10 indirme")
    }
    static var premiumCardActiveBadge: String { tr("premiumCard.activeBadge", "AKTİF") }
    static var premiumCardBadge: String { tr("premiumCard.badge", "PREMIUM") }
    static var premiumCardReadPerk: String { tr("premiumCard.readPerk", "10 okuma") }
    static var premiumCardDownloadPerk: String { tr("premiumCard.downloadPerk", "10 indirme") }
    static var premiumCardActiveNote: String {
        tr("premiumCard.activeNote", "Premium okuma ve indirme hakkınız aktif.")
    }
    static func premiumCardRemainingDays(_ days: Int) -> String {
        String(format: tr("premiumCard.remainingDays", "Premium bitişine %d gün kaldı."), days)
    }
    static var premiumCardDiscover: String { tr("premiumCard.discover", "Avantajları keşfet") }

    static var profileMetricComments: String { tr("profile.metric.comments", "Yorum / Mesaj") }
    static var profileMetricReactions: String { tr("profile.metric.reactions", "Reaksiyon") }
    static var profileMetricPoints: String { tr("profile.metric.points", "Puan") }

    static var profileInfoTitle: String { tr("profile.info.title", "E-Kitaplığım Üyelik Bilgileri") }
    static var profileInfoSubtitle: String { tr("profile.info.subtitle", "Hesabına ait temel üyelik ayrıntıları") }
    static var profileInfoActiveBadge: String { tr("profile.info.activeBadge", "AKTİF") }
    static var profileInfoAbout: String { tr("profile.info.about", "Hakkımda") }
    static var profileInfoLocation: String { tr("profile.info.location", "Konum") }
    static var profileInfoWebsite: String { tr("profile.info.website", "Web sitesi") }
    static var profileInfoRegisterDate: String { tr("profile.info.registerDate", "Kayıt tarihi") }
    static var profileInfoLastActivity: String { tr("profile.info.lastActivity", "Son aktivite") }
    static var profileInfoOnlineStatus: String { tr("profile.info.onlineStatus", "Çevrimiçi durum") }
    static var profileInfoVisible: String { tr("profile.info.visible", "Görünür") }
    static var profileInfoHidden: String { tr("profile.info.hidden", "Gizli") }

    static var profileLogout: String { tr("profile.logout", "Çıkış Yap") }
    static var profileDeleteRequest: String { tr("profile.deleteRequest", "Hesap silme talebi") }
    static var profileDeleteRequestMessage: String {
        tr(
            "profile.deleteRequestMessage",
            "Bu işlem E-Kitaplığım hesabınızın, profil bilgilerinizin ve hesapla ilişkili verilerin silinmesi için yönetim ekibine talep gönderir."
        )
    }
    static var profileDeleteRequestConfirm: String { tr("profile.deleteRequestConfirm", "Talep Gönder") }
    static var profileDeleteRequestSent: String {
        tr("profile.deleteRequestSent", "Hesap silme talebiniz yönetim ekibine iletildi.")
    }
    static var profileDeleteRequestFailed: String { tr("profile.deleteRequestFailed", "Hesap silme talebi gönderilemedi.") }

    static var profileGuestTitle: String { tr("profile.guest.title", "Kütüphanene hoş geldin") }
    static var profileGuestSubtitle: String {
        tr("profile.guest.subtitle", "Raflarını senkronla, okuma limitlerini takip et ve favorilerini sakla.")
    }
    static var profileGuestShelfSync: String { tr("profile.guest.shelfSync", "Raf senkronu") }
    static var profileGuestLimits: String { tr("profile.guest.limits", "Limit takibi") }
    static var profileGuestFavorites: String { tr("profile.guest.favorites", "Favoriler") }
    static var profileGuestSecure: String { tr("profile.guest.secure", "Güvenli erişim") }
    static var profileGuestFooter: String { tr("profile.guest.footer", "Güvenli bağlantı ile verileriniz korunur.") }

    static var profileLibrarySectionTitle: String { tr("profile.librarySection.title", "Kişisel Kütüphanem") }
    static var profileLibrarySectionSubtitle: String {
        tr("profile.librarySection.subtitle", "Kitapların ve okuma ilerlemen tek yerde")
    }
    static var profileMyBooks: String { tr("profile.myBooks", "Kitaplarım") }
    static var profilePostsSubtitle: String { tr("profile.posts.subtitle", "Forum paylaşımların ve yorumların") }
    static var profilePostsEmpty: String { tr("profile.posts.empty", "Henüz görüntülenecek gönderi bulunmuyor.") }
    static var profilePostBadge: String { tr("profile.posts.badge", "YORUM") }
    static var profileActivityEmpty: String { tr("profile.activity.empty", "Henüz görüntülenecek aktivite bulunmuyor.") }
    static var profileAboutStoryTitle: String { tr("profile.about.storyTitle", "Benim hikâyem") }
    static var profileAboutSummaryTitle: String { tr("profile.about.summaryTitle", "Üyelik özeti") }
    static var profileAboutEmpty: String { tr("profile.about.empty", "Henüz bir hakkında yazısı eklenmemiş.") }
    static var profileAboutEditAction: String { tr("profile.about.editAction", "Profil bilgilerini düzenle") }
    static var profileBadgesEmpty: String { tr("profile.badges.empty", "Henüz rozet kazanılmamış.") }
    static var profileBadgesTitle: String { tr("profile.badges.title", "Kazanılan rozetler") }
    static func profileBadgePoints(_ value: Int) -> String { String(format: tr("profile.badges.points", "%d puan"), value) }

    static var profileSectionTabsAccessibility: String { tr("profile.sectionTabs.accessibility", "Profil bölümleri") }
    static var profileTabProfileSubtitle: String { tr("profile.tab.profileSubtitle", "Profil bilgilerin ve üyelik detayların") }
    static var profileTabPostsSubtitle: String { tr("profile.tab.postsSubtitle", "Forum paylaşımların ve yorumların") }
    static var profileTabActivitySubtitle: String { tr("profile.tab.activitySubtitle", "Okuma ve forum hareketlerin") }
    static var profileTabAboutSubtitle: String { tr("profile.tab.aboutSubtitle", "Okuma yolculuğundan kısa bir not") }
    static var profileTabBadgesSubtitle: String { tr("profile.tab.badgesSubtitle", "Okuma ve topluluk başarıların") }
    static var profileLibraryEmpty: String { tr("profile.library.empty", "Kütüphanende henüz kitap bulunmuyor.") }
    static var profileReadingList: String { tr("profile.readingList", "Okuma listem") }
    static var profileMemberGroup: String { tr("profile.memberGroup", "Üye grubu") }
    static var profileMemberFallbackGroup: String { tr("profile.memberFallbackGroup", "Üye") }
    static var profileForumPost: String { tr("profile.forumPost", "Forum gönderisi") }
    static var profileBadgeEarned: String { tr("profile.badgeEarned", "Kazanılmış Rozet") }
    static var profileBadgeEarnedMessage: String { tr("profile.badgeEarnedMessage", "Bu rozeti başarıyla kazandın.") }
    static func profileBadgeEarnedOn(_ date: String) -> String {
        String(format: tr("profile.badgeEarnedOn", "%@ tarihinde kazanıldı."), date)
    }

    // MARK: - Profil düzenleme ve istatistikler

    static var profileEditPhotoSection: String { tr("profile.edit.photoSection", "Profil görselleri") }
    static var profileEditAvatar: String { tr("profile.edit.avatar", "Profil fotoğrafı") }
    static var profileEditBanner: String { tr("profile.edit.banner", "Profil afişi") }
    static var profileEditChoosePhoto: String { tr("profile.edit.choosePhoto", "Görsel seç") }
    static var profileEditUploading: String { tr("profile.edit.uploading", "Yükleniyor…") }
    static var profileEditUploadFailed: String { tr("profile.edit.uploadFailed", "Görsel yüklenemedi.") }
    static var profileEditUploadUnavailable: String {
        tr("profile.edit.uploadUnavailable", "Görsel yükleme şu anda sunucuda kullanılamıyor.")
    }
    static var profileEditImageTooLarge: String { tr("profile.edit.imageTooLarge", "Görsel en fazla 12 MB olabilir.") }

    static var statsTitle: String { tr("stats.title", "Okuma Analitiği") }
    static var statsSubtitle: String { tr("stats.subtitle", "Okuma alışkanlıklarını takip et") }
    static var statsGoalSectionTitle: String { tr("stats.goalSection.title", "Günlük hedefin") }
    static func statsGoalMinutes(_ value: Int) -> String { String(format: tr("stats.goalMinutes", "%d dakika"), value) }
    static var statsGoalSaveFailed: String { tr("stats.goalSaveFailed", "Günlük hedef kaydedilemedi.") }
    static var statsGoalUnavailable: String {
        tr("stats.goalUnavailable", "Günlük hedef ayarı şu anda sunucuda kullanılamıyor.")
    }
    static var statsTotalPages: String { tr("stats.totalPages", "Toplam sayfa") }
    static var statsTotalDuration: String { tr("stats.totalDuration", "Toplam süre") }
    static var statsStreak: String { tr("stats.streak", "Okuma serisi") }
    static var statsTodayTitle: String { tr("stats.todayTitle", "Bugün") }

    // MARK: - Kitap Gündemi

    static var agendaTitle: String { tr("agenda.title", "Kitap Gündemi") }
    static var agendaSubtitle: String { tr("agenda.subtitle", "Okurların notları, alıntıları ve incelemeleri") }
    static var agendaDetailSubtitle: String { tr("agenda.detailSubtitle", "Gönderi ve yorumlar") }
    static var agendaHeroEyebrow: String { tr("agenda.heroEyebrow", "OKUDUĞUNU PAYLAŞ") }
    static var agendaHeroBody: String { tr("agenda.heroBody", "Kitaplardan konuş, yeni fikirler ve okurlar keşfet.") }
    static var agendaRefresh: String { tr("agenda.refresh", "Gündemi yenile") }

    static var agendaTabPersonal: String { tr("agenda.tab.personal", "Sana Özel") }
    static var agendaTabPersonalSubtitle: String { tr("agenda.tab.personalSubtitle", "Senin için") }
    static var agendaTabFollowing: String { tr("agenda.tab.following", "Takip Ettiklerin") }
    static var agendaTabFollowingSubtitle: String { tr("agenda.tab.followingSubtitle", "Üyeler ve raflar") }
    static var agendaTabAgenda: String { tr("agenda.tab.agenda", "Kitap Gündemi") }
    static var agendaTabAgendaSubtitle: String { tr("agenda.tab.agendaSubtitle", "Toplulukta bugün") }
    static var agendaTabLocked: String { tr("agenda.tab.locked", "Giriş gerekli") }

    static var agendaFilterAll: String { tr("agenda.filter.all", "Tümü") }
    static var agendaFilterBooks: String { tr("agenda.filter.books", "Kitaplar") }
    static var agendaFilterReviews: String { tr("agenda.filter.reviews", "İncelemeler") }
    static var agendaFilterQuotations: String { tr("agenda.filter.quotations", "Alıntılar") }
    static var agendaFilterProgress: String { tr("agenda.filter.progress", "Okuma") }
    static var agendaFilterPopular: String { tr("agenda.filter.popular", "Popüler") }
    static var agendaFilterSaved: String { tr("agenda.filter.saved", "Kaydedilenler") }

    static var agendaTypeBook: String { tr("agenda.type.book", "Kitap") }
    static var agendaTypeQuotation: String { tr("agenda.type.quotation", "Alıntı") }
    static var agendaTypeReview: String { tr("agenda.type.review", "İnceleme") }
    static var agendaTypeProgress: String { tr("agenda.type.progress", "Okuma") }
    static var agendaTypeQuote: String { tr("agenda.type.quote", "Alıntılandı") }
    static var agendaTypeStandard: String { tr("agenda.type.standard", "Paylaşım") }
    static var agendaTypeNote: String { tr("agenda.type.note", "Not") }
    static var agendaTypeProgressCompose: String { tr("agenda.type.progressCompose", "İlerleme") }

    static var agendaPinned: String { tr("agenda.pinned", "Sabitlendi") }
    static var agendaFeatured: String { tr("agenda.featured", "Öne çıkan") }
    static var agendaFollow: String { tr("agenda.follow", "Takip et") }
    static var agendaFollowing: String { tr("agenda.following", "Takipte") }
    static var agendaProgressLabel: String { tr("agenda.progressLabel", "Okuma ilerlemesi") }
    static func agendaPageLabel(_ page: Int) -> String { String(format: tr("agenda.pageLabel", "Sayfa %d"), page) }
    static func agendaQuotedFrom(_ username: String) -> String {
        String(format: tr("agenda.quotedFrom", "%@ adlı üyeden alıntı"), username)
    }
    static var agendaOpenBook: String { tr("agenda.openBook", "Kitabı aç") }
    static var agendaPostImage: String { tr("agenda.postImage", "Gönderi görseli") }
    static var agendaReact: String { tr("agenda.react", "Beğen") }
    static var agendaComments: String { tr("agenda.comments", "Yorumlar") }
    static var agendaRepost: String { tr("agenda.repost", "Yeniden paylaş") }
    static var agendaBookmark: String { tr("agenda.bookmark", "Kaydet") }

    static var agendaComposerPromptTitle: String { tr("agenda.composer.promptTitle", "Yeni bir paylaşım oluştur") }
    static var agendaComposerPromptSubtitle: String {
        tr("agenda.composer.promptSubtitle", "Ne okuyorsun ya da ne paylaşmak istiyorsun?")
    }
    static var agendaComposerGuestTitle: String { tr("agenda.composer.guestTitle", "Topluluğa katıl") }
    static var agendaComposerGuestSubtitle: String {
        tr("agenda.composer.guestSubtitle", "Paylaşmak ve etkileşim kurmak için giriş yap.")
    }
    static var agendaComposerTitle: String { tr("agenda.composer.title", "Yeni paylaşım") }
    static var agendaComposerSubtitle: String { tr("agenda.composer.subtitle", "Okuma deneyimini toplulukla paylaş.") }
    static var agendaComposerSelectBook: String { tr("agenda.composer.selectBook", "Kitap seç") }
    static var agendaComposerSearchBook: String { tr("agenda.composer.searchBook", "Kitap veya yazar ara") }
    static var agendaComposerQuotePlaceholder: String { tr("agenda.composer.quotePlaceholder", "Alıntıyı yaz...") }
    static var agendaComposerPlaceholder: String { tr("agenda.composer.placeholder", "Ne paylaşmak istiyorsun?") }
    static var agendaComposerPageNumber: String { tr("agenda.composer.pageNumber", "Sayfa numarası") }
    static func agendaComposerRating(_ value: Int) -> String { String(format: tr("agenda.composer.rating", "Puan: %d/5"), value) }
    static var agendaComposerReviewTitle: String { tr("agenda.composer.reviewTitle", "İnceleme başlığı") }
    static var agendaComposerProgressCurrent: String { tr("agenda.composer.progressCurrent", "Şu an") }
    static var agendaComposerProgressTotal: String { tr("agenda.composer.progressTotal", "Toplam") }
    static var agendaComposerSubmit: String { tr("agenda.composer.submit", "Paylaş") }
    static var agendaComposerSubmitting: String { tr("agenda.composer.submitting", "Paylaşılıyor") }
    static var agendaComposerEmptyMessage: String { tr("agenda.composer.emptyMessage", "Paylaşım metni boş olamaz.") }
    static var agendaComposerBookRequired: String {
        tr("agenda.composer.bookRequired", "Bu paylaşım türü için kitap seçmelisin.")
    }
    static var agendaComposerProgressInvalid: String {
        tr("agenda.composer.progressInvalid", "İlerleme sayfası toplam sayfadan büyük olamaz.")
    }
    static var agendaComposerFailed: String { tr("agenda.composer.failed", "Paylaşım gönderilemedi.") }

    static func agendaCommentsHeader(_ count: Int) -> String {
        String(format: tr("agenda.commentsHeader", "Yorumlar · %d"), count)
    }
    static var agendaCommentsEmptyTitle: String { tr("agenda.comments.emptyTitle", "Henüz yorum yok") }
    static var agendaCommentsEmptySubtitle: String { tr("agenda.comments.emptySubtitle", "İlk yorumu sen yazabilirsin.") }
    static var agendaCommentComposerTitle: String { tr("agenda.comment.composerTitle", "Yorumunu paylaş") }
    static var agendaCommentGuestTitle: String { tr("agenda.comment.guestTitle", "Yorum yapmak için giriş yap") }
    static var agendaCommentPlaceholder: String { tr("agenda.comment.placeholder", "Kitap hakkında ne düşünüyorsun?") }
    static var agendaCommentSubmit: String { tr("agenda.comment.submit", "Yorum yap") }
    static var agendaCommentSubmitting: String { tr("agenda.comment.submitting", "Gönderiliyor") }
    static var agendaCommentFailed: String { tr("agenda.comment.failed", "Yorum gönderilemedi.") }
    static var agendaCommentEditTitle: String { tr("agenda.comment.editTitle", "Yorumu düzenle") }
    static var agendaCommentUpdateFailed: String { tr("agenda.comment.updateFailed", "Yorum güncellenemedi.") }
    static var agendaCommentDeleteTitle: String { tr("agenda.comment.deleteTitle", "Yorumu sil") }
    static var agendaCommentDeleteMessage: String { tr("agenda.comment.deleteMessage", "Bu yorum kalıcı olarak silinecek.") }
    static var agendaCommentDeleteFailed: String { tr("agenda.comment.deleteFailed", "Yorum silinemedi.") }

    static var agendaPostEditTitle: String { tr("agenda.post.editTitle", "Paylaşımı düzenle") }
    static var agendaPostLabel: String { tr("agenda.post.label", "Paylaşım") }
    static var agendaPostVisibilityTitle: String { tr("agenda.post.visibilityTitle", "Kimler görebilir?") }
    static var agendaVisibilityPublic: String { tr("agenda.visibility.public", "Herkes") }
    static var agendaVisibilityMembers: String { tr("agenda.visibility.members", "Üyeler") }
    static var agendaVisibilityFollowers: String { tr("agenda.visibility.followers", "Takipçiler") }
    static var agendaVisibilityPrivate: String { tr("agenda.visibility.private", "Yalnızca ben") }
    static var agendaPostUpdateFailed: String { tr("agenda.post.updateFailed", "Paylaşım güncellenemedi.") }
    static var agendaPostDeleteTitle: String { tr("agenda.post.deleteTitle", "Paylaşımı sil") }
    static var agendaPostDeleteMessage: String {
        tr("agenda.post.deleteMessage", "Bu paylaşım ve ona bağlı yorumlar kaldırılacak. Devam edilsin mi?")
    }
    static var agendaPostDeleteFailed: String { tr("agenda.post.deleteFailed", "Paylaşım silinemedi.") }

    static var agendaActionFailed: String { tr("agenda.actionFailed", "İşlem tamamlanamadı.") }
    static var agendaFollowFailed: String { tr("agenda.followFailed", "Takip durumu güncellenemedi.") }
    static var agendaFollowUnavailable: String {
        tr("agenda.followUnavailable", "Takip özelliği şu anda sunucuda kullanılamıyor.")
    }
    static var agendaFeedErrorTitle: String { tr("agenda.feed.errorTitle", "Akış yüklenemedi") }
    static var agendaFeedEmptyTitle: String { tr("agenda.feed.emptyTitle", "Bu rafta henüz paylaşım yok") }
    static var agendaFeedEmptySubtitle: String {
        tr("agenda.feed.emptySubtitle", "İlk kitap notunu sen paylaşabilirsin.")
    }
    static var agendaFeedLoadFailed: String { tr("agenda.feed.loadFailed", "Kitap Gündemi yüklenemedi.") }
    static var agendaDetailErrorTitle: String { tr("agenda.detail.errorTitle", "Gönderi yüklenemedi") }
    static var agendaDetailErrorMessage: String {
        tr("agenda.detail.errorMessage", "Bu gönderi kaldırılmış veya görünür olmayabilir.")
    }

    // MARK: - Okur Sohbeti

    static var chatTitle: String { tr("chat.title", "Okur Sohbeti") }
    static var chatSubtitle: String { tr("chat.subtitle", "Kitapları birlikte konuşalım") }
    static var chatRefresh: String { tr("chat.refresh", "Sohbeti yenile") }
    static var chatTimeNow: String { tr("chat.timeNow", "Şimdi") }
    static var chatEdited: String { tr("chat.edited", " · düzenlendi") }
    static var chatRoleAdmin: String { tr("chat.role.admin", "YÖNETİCİ") }
    static var chatRoleModerator: String { tr("chat.role.moderator", "MODERATÖR") }
    static var chatRoomFallbackDescription: String {
        tr("chat.roomFallbackDescription", "Kitaplar üzerine canlı sohbet")
    }
    static func chatOnlineCount(_ value: Int) -> String { String(format: tr("chat.onlineCount", "%d çevrimiçi"), value) }
    static var chatRoomOpen: String { tr("chat.roomOpen", "Açık") }
    static var chatLiveBadge: String { tr("chat.liveBadge", "CANLI") }

    static var chatStatusMember: String { tr("chat.status.member", "Üye olarak bağlısın") }
    static var chatStatusSecureRead: String { tr("chat.status.secureRead", "Güvenli okuma modu") }
    static var chatStatusGuest: String { tr("chat.status.guest", "Misafir olarak izliyorsun") }
    static var chatWelcomeReady: String { tr("chat.welcome.ready", "Sohbete katılmaya hazırsın") }
    static var chatWelcomeSecure: String {
        tr("chat.welcome.secure", "Mesajlar güvenli okuma modunda gösteriliyor")
    }
    static var chatWelcomeGuest: String {
        tr("chat.welcome.guest", "Misafir olarak canlı mesajları takip ediyorsun")
    }
    static var chatWelcomeRules: String {
        tr("chat.welcome.rules", "Topluluk kurallarına saygı göstererek kitapları birlikte konuşalım.")
    }

    static var chatComposerPlaceholder: String { tr("chat.composer.placeholder", "Okurlarla paylaş…") }
    static var chatComposerSend: String { tr("chat.composer.send", "Gönder") }
    static var chatComposerGuestTitle: String { tr("chat.composer.guestTitle", "Sohbete sen de katıl") }
    static var chatComposerGuestSubtitle: String {
        tr("chat.composer.guestSubtitle", "Mesaj yazmak ve okurlarla buluşmak için giriş yap.")
    }
    static var chatComposerReadOnlyTitle: String { tr("chat.composer.readOnlyTitle", "Bu oda okuma modunda") }
    static var chatComposerReadOnlySubtitle: String {
        tr("chat.composer.readOnlySubtitle", "Duyuruları ve yeni mesajları buradan takip edebilirsin.")
    }
    static var chatComposerNoPermission: String {
        tr("chat.composer.noPermission", "Bu hesap için mesaj gönderme yetkisi bulunmuyor.")
    }
    static var chatComposerDisabled: String {
        tr("chat.composer.disabled", "Bu odada sohbet devre dışı.")
    }
    static var chatSendFailed: String { tr("chat.sendFailed", "Mesaj gönderilemedi. Lütfen tekrar deneyin.") }

    static var chatRoomsLoading: String { tr("chat.roomsLoading", "Sohbet odaları hazırlanıyor…") }
    static var chatRoomsLoadingSubtitle: String {
        tr("chat.roomsLoadingSubtitle", "Canlı topluluk bağlantısı kuruluyor")
    }
    static var chatRoomsFailed: String { tr("chat.roomsFailed", "Sohbet odaları yüklenemedi.") }
    static var chatRoomsEmpty: String {
        tr("chat.roomsEmpty", "Şu anda katılabileceğiniz bir sohbet odası yok.")
    }
    static var chatMessagesLoading: String { tr("chat.messagesLoading", "Mesajlar yükleniyor…") }
    static var chatMessagesEmpty: String {
        tr("chat.messagesEmpty", "Bu odada henüz mesaj yok. İlk mesajı sen yazabilirsin.")
    }
    static var chatReconnectTitle: String { tr("chat.reconnectTitle", "Topluluğa yeniden bağlanalım") }
    static var chatReconnect: String { tr("chat.reconnect", "Tekrar bağlan") }
    static var chatLoadOlder: String { tr("chat.loadOlder", "Önceki mesajları göster") }

    // MARK: - Canlı Aktivite

    static var liveActivityTitle: String { tr("liveActivity.title", "Canlı Aktivite") }
    static var liveActivitySubtitle: String { tr("liveActivity.subtitle", "Toplulukta şu anda neler oluyor?") }
    static var liveActivityHeroEyebrow: String {
        tr("liveActivity.heroEyebrow", "HER KİTAP YENİ BİR HAREKET BAŞLATIR")
    }
    static var liveActivityHeroBody: String {
        tr("liveActivity.heroBody", "Okurların keşiflerini ve raf hareketlerini anlık takip et.")
    }
    static var liveActivityBadge: String { tr("liveActivity.badge", "CANLI") }
    static var liveActivityRefresh: String { tr("liveActivity.refresh", "Akışı yenile") }
    static var liveActivityErrorTitle: String { tr("liveActivity.errorTitle", "Akış yüklenemedi") }
    static var liveActivityEmptyTitle: String { tr("liveActivity.emptyTitle", "Henüz hareket yok") }
    static var liveActivityEmptySubtitle: String {
        tr("liveActivity.emptySubtitle", "Yeni kitap ve topluluk hareketleri burada görünecek.")
    }
    static var liveActivityLoadFailed: String { tr("liveActivity.loadFailed", "Canlı akış yüklenemedi.") }

    static var liveActivityTypeJoin: String { tr("liveActivity.type.join", "Yeni üye") }
    static var liveActivityTypeFavorite: String { tr("liveActivity.type.favorite", "Favori") }
    static var liveActivityTypeReading: String { tr("liveActivity.type.reading", "Okuma listesi") }
    static var liveActivityTypeRead: String { tr("liveActivity.type.read", "Tamamlandı") }
    static var liveActivityTypeDownload: String { tr("liveActivity.type.download", "İndirme") }
    static var liveActivityTypeRating: String { tr("liveActivity.type.rating", "Puanlama") }
    static var liveActivityTypeComment: String { tr("liveActivity.type.comment", "Yorum") }
    static var liveActivityTypeReview: String { tr("liveActivity.type.review", "İnceleme") }
    static var liveActivityTypeAgenda: String { tr("liveActivity.type.agenda", "Kitap Gündemi") }
    static var liveActivityTypeChat: String { tr("liveActivity.type.chat", "Okur sohbeti") }
    static var liveActivityTypeRequest: String { tr("liveActivity.type.request", "Kitap isteği") }
    static var liveActivityTypeGeneric: String { tr("liveActivity.type.generic", "Kitap hareketi") }

    // MARK: - Ana sayfa

    static var homeHeroBadge: String { tr("home.hero.badge", "SON EKLENENLER") }
    static var homeHeroHeadline: String { tr("home.hero.headline", "Yeni kitaplar şimdi rafında") }
    static var homeHeroSubtitle: String {
        tr("home.hero.subtitle", "Kütüphaneye yeni katılan kitapları keşfet, okumaya hemen başla.")
    }
    static var homeHeroPrimaryAction: String { tr("home.hero.primaryAction", "Yeni Kitaplar") }
    static var homeSignalFormats: String { tr("home.signal.formats", "PDF & EPUB") }
    static var homeSignalShelfSync: String { tr("home.signal.shelfSync", "Raf senkronu") }
    static var homeSignalEverywhere: String { tr("home.signal.everywhere", "Her yerde oku") }
    static var homeSearchPlaceholder: String {
        tr("home.searchPlaceholder", "Kitap, yazar, yayınevi veya ISBN ara...")
    }
    static var homeStatBooks: String { tr("home.stat.books", "E-kitap") }
    static var homeStatAuthors: String { tr("home.stat.authors", "Yazar") }
    static var homeStatPublishers: String { tr("home.stat.publishers", "Yayınevi") }
    static var homeContinueTitle: String { tr("home.continueTitle", "Kaldığın yerden devam et") }
    static var homeContinueAction: String { tr("home.continueAction", "Devam Et") }
    static var homeDiscoveryTitle: String { tr("home.discovery.title", "Keşif Merkezi") }
    static var homeDiscoverySubtitle: String {
        tr("home.discovery.subtitle", "Gündemi yakala, sohbete katıl, topluluğu canlı takip et")
    }
    static var homeDiscoveryCatalogBadge: String { tr("home.discovery.catalogBadge", "KİTAP KATALOĞU") }
    static var homeDiscoveryCatalogSubtitle: String {
        tr("home.discovery.catalogSubtitle", "Binlerce kitabı keşfet")
    }
    static var homeDiscoveryAgendaBadge: String { tr("home.discovery.agendaBadge", "GÜNDEM") }
    static var homeDiscoveryAgendaSubtitle: String {
        tr("home.discovery.agendaSubtitle", "Okurlar bugün ne paylaşıyor?")
    }
    static var homeDiscoveryChatBadge: String { tr("home.discovery.chatBadge", "SOHBET") }
    static var homeDiscoveryChatSubtitle: String {
        tr("home.discovery.chatSubtitle", "Canlı sohbete hemen katıl")
    }
    static var homeDiscoveryLiveBadge: String { tr("home.discovery.liveBadge", "CANLI") }
    static var homeDiscoveryLiveTitle: String { tr("home.discovery.liveTitle", "Canlı Akış") }
    static var homeDiscoveryLiveSubtitle: String {
        tr("home.discovery.liveSubtitle", "Topluluktaki son hareketler")
    }
    static var homeDiscoveryRequestsBadge: String { tr("home.discovery.requestsBadge", "TOPLULUK") }
    static var homeDiscoveryRequestsSubtitle: String {
        tr("home.discovery.requestsSubtitle", "Topluluğa kitap öner")
    }
    static var homeDiscoveryForumBadge: String { tr("home.discovery.forumBadge", "FORUM") }
    static var homeDiscoveryForumSubtitle: String {
        tr("home.discovery.forumSubtitle", "Yeni konulara göz at")
    }
    static var homeDiscoveryProfileBadge: String { tr("home.discovery.profileBadge", "HESABIM") }
    static var homeDiscoveryProfileSubtitle: String {
        tr("home.discovery.profileSubtitle", "Hesabını ve rafını yönet")
    }
    static var homeAgendaRailSubtitle: String {
        tr("home.agendaRail.subtitle", "Okurların kitap notları, alıntıları ve değerlendirmeleri")
    }
    static var homeAgendaRailEmpty: String {
        tr("home.agendaRail.empty", "Kitap Gündemi'ni aç ve okurların paylaşımlarını keşfet.")
    }
    static var homeChatCardSubtitle: String { tr("home.chatCard.subtitle", "Okurlar şimdi ne konuşuyor?") }
    static var homeChatCardEmpty: String {
        tr("home.chatCard.empty", "Sohbet odasını aç, kitaplardan konuşmaya hemen katıl.")
    }
    static var homeChatCardAction: String { tr("home.chatCard.action", "Sohbete katıl") }
    static var homeLiveCardEyebrow: String { tr("home.liveCard.eyebrow", "TOPLULUK ŞİMDİ") }
    static var homeLiveCardSubtitle: String { tr("home.liveCard.subtitle", "Okurların son kitap hareketleri") }
    static var homeLiveCardEmpty: String {
        tr("home.liveCard.empty", "Yeni üyeleri, kitap keşiflerini ve raf hareketlerini anlık takip et.")
    }
    static var homeLiveCardAction: String { tr("home.liveCard.action", "Tümünü gör") }
    static var homeDailyPickTitle: String { tr("home.dailyPick.title", "Bugünün Seçkisi") }
    static var homeDailyPickSubtitle: String {
        tr("home.dailyPick.subtitle", "Roman raflarından günlük rastgele seçki")
    }
    static var homeNewestTitle: String { tr("home.newest.title", "Yeni Eklenenler") }
    static var homeNewestSubtitle: String { tr("home.newest.subtitle", "Kütüphaneye son katılan raflar") }
    static var homePopularTitle: String { tr("home.popular.title", "Çok Okunanlar") }
    static var homePopularSubtitle: String {
        tr("home.popular.subtitle", "Her yenilemede farklı popüler raflar")
    }
    static var homePremiumRailTitle: String { tr("home.premiumRail.title", "Premium Üyelere Özel") }
    static var homePremiumRailSubtitle: String {
        tr("home.premiumRail.subtitle", "Ayrıcalıklı okuma deneyimi")
    }
    static var homeRequestCenterTitle: String { tr("home.requestCenter.title", "Kitap İstek Merkezi") }
    static var homeRequestCenterSubtitle: String {
        tr(
            "home.requestCenter.subtitle",
            "Topluluğa öner, destekleri topla, yeni kitapların raflara katılmasına yardım et."
        )
    }
    static var homeRequestCenterAction: String { tr("home.requestCenter.action", "İstek Gönder") }

    // MARK: - Kütüphane sekmeleri

    static var libraryTabReading: String { tr("library.tab.reading", "Okuyorum") }
    static var libraryTabWantToRead: String { tr("library.tab.wantToRead", "Okuyacağım") }
    static var libraryTabFinished: String { tr("library.tab.finished", "Okudum") }
    static var libraryTabFavorites: String { tr("library.tab.favorites", "Favoriler") }
    static var libraryTabDownloads: String { tr("library.tab.downloads", "İndirmeler") }
    static var libraryHeaderTitle: String { tr("library.header.title", "Kişisel Kitaplığım") }

    private static func tr(_ key: String, _ defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: nil)
    }
}
