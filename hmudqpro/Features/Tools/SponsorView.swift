import SwiftUI

/// 赞助开发者（简版）：项目卡片 + 收款/凭证图；完整打赏（支付/榜单/留言）见 P3。
struct SponsorView: View {
    @State private var overview: DonateOverview?

    struct DonateOverview: Decodable {
        let projectName: String
        let projectImageURL: String
        let proofImageURL: String

        enum CodingKeys: String, CodingKey {
            case projectName = "project_name"
            case projectImageURL = "project_image_url"
            case proofImageURL = "proof_image_url"
        }
    }

    var body: some View {
        List {
            if let o = overview {
                Section(String(localized: "sponsor.project")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(o.projectName).font(.headline)
                        if let url = URL(string: o.projectImageURL) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                            }
                            .cornerRadius(8)
                        }
                    }
                }
                Section(String(localized: "sponsor.proof")) {
                    if let url = URL(string: o.proofImageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 120)
                        }
                        .cornerRadius(8)
                    }
                }
            } else {
                HStack { Spacer(); ProgressView(); Spacer() }
            }
            Section {
                Text(String(localized: "sponsor.hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "tool.sponsor"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let (data, _) = try? await APIClient.shared.request(APIConfig.donateOverviewURL,
                                                                   userAgent: APIConfig.appUserAgent),
               let o = try? JSONDecoder().decode(DonateOverview.self, from: data) {
                overview = o
            }
        }
    }
}
