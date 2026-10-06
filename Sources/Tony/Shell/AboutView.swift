import SwiftUI

/// The AGPL's "Appropriate Legal Notices" and the credits the model licenses ask for.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            VStack(spacing: 2) {
                Text("Tony").font(.system(size: 22, weight: .bold))
                Text("Version \(Bundle.main.version)").foregroundStyle(.secondary)
            }
            VStack(spacing: 4) {
                Text("Copyright © 2026 Best Boy")
                Text("Free software under the GNU Affero General Public License, version 3, with ABSOLUTELY NO WARRANTY.")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Link("Source Code", destination: URL(string: "https://github.com/bestboyhq/tony")!)
                Link("License", destination: URL(string: "https://www.gnu.org/licenses/agpl-3.0.html")!)
            }
            .font(.callout)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                credit("Parakeet TDT 0.6B v3", "by NVIDIA, post-trained as Parakeet Ultra by Moondream and converted to Core ML by FluidInference.", license: "CC\u{00A0}BY\u{00A0}4.0", url: "https://creativecommons.org/licenses/by/4.0/")
                credit("Parakeet CTC 110M", "by NVIDIA, converted to Core ML by FluidInference, listens for your words.", license: "CC\u{00A0}BY\u{00A0}4.0", url: "https://creativecommons.org/licenses/by/4.0/")
                credit("Silero VAD", "by Silero Team, for voice activity detection.", license: "MIT", url: "https://github.com/snakers4/silero-vad")
                credit("FluidAudio", "by FluidInference, runs the models on the Neural Engine.", license: "Apache\u{00A0}2.0", url: "https://github.com/FluidInference/FluidAudio")
                credit("Sparkle", "by the Sparkle Project, for updates.", license: "MIT", url: "https://sparkle-project.org")
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .frame(width: 380)
    }

    private func credit(_ name: String, _ detail: String, license: String, url: String) -> some View {
        Text((try? AttributedString(markdown: "**\(name)** \(detail) [\(license)](\(url))")) ?? AttributedString(name))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
