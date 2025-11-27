import SwiftUI

struct LibraryToolbar: ViewModifier {
    @ObservedObject private var nav = NavigationCoordinator.shared

    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: titleText,
                leading: {
                    if !isAtRoot {
                        Button {
                            nav.openLibraryRoot()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                },
                trailing: {
                    EmptyView()
                }
            )
    }

    // MARK: Title / State

    private var isAtRoot: Bool {
        nav.libraryRoute == .root
    }

    private var titleText: String {
        switch nav.libraryRoute {
        case .root:
            return "Фонотека"
        case .folder(let id):
            return MusicLibraryManager.shared.folder(for: id)?.name ?? "Папка"
        }
    }
}

// MARK: Modifier

extension View {
    func libraryToolbar() -> some View {
        self.modifier(LibraryToolbar())
    }
}
