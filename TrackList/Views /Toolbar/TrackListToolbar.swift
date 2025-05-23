//
//  TrackListToolbar
//  TrackList
//
//  Тулбар раздела "Треклист"
//
//  Created by Pavel Fomin on 16.05.2025.
//

import SwiftUI

struct TrackListToolbar: View {
    let isEditing: Bool
    let hasTrackLists: Bool
    let onAdd: () -> Void
    let onToggleEditMode: () -> Void
    
    var body: some View {
        HStack {
            // Заголовок
            Text("TRACKLIST")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.primary)
                .padding(.top, 4)
            
            Spacer()
            
            // Режим редактирования
            if hasTrackLists {
                Button(action: onToggleEditMode) {
                    Image(systemName: "wand.and.sparkles.inverse")
                        .font(.title2)
                }
            }
                
                // Новый треклист
            Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .padding(.leading, 12)
                }
            }
            
        }
    }

