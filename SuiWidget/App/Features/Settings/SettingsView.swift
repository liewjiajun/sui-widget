import SwiftUI
import SuiWidgetKit

/// V1 Task 13 fills in the full Settings; this stub exposes Wallets nav reachability now.
struct SettingsView: View {
    var body: some View {
        Form {
            Section("Account") {
                NavigationLink {
                    WalletListView()
                } label: {
                    Label("Wallets", systemImage: "wallet.pass")
                }
            }
            Section {
                Text("Display + Data + About land in V1 Task 13.")
                    .font(SuiTypography.body(12))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
