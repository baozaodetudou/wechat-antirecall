import XCTest
@testable import WeChatAntiRecallGUI

final class GUIInstallRequestTests: XCTestCase {
    private let configURL = URL(fileURLWithPath: "/tmp/patches.json")
    private let runtimeURL = URL(fileURLWithPath: "/tmp/libWeChatAntiRecallRuntime.dylib")

    func testCombinedModePassesPreserveWithTipToCLI() {
        let arguments = InstallRequest(mode: .preserveWithTip).arguments(
            appPath: "/Applications/WeChat.app",
            configURL: configURL,
            runtimeDylibURL: runtimeURL,
            dryRun: false
        )

        XCTAssertTrue(arguments.contains("--preserve-with-tip"))
        XCTAssertFalse(arguments.contains("--runtime-tip"))
        XCTAssertEqual(Array(arguments.suffix(2)), ["--runtime-dylib", runtimeURL.path])
    }

    func testOnlyTipModesUseCustomTipRuntime() {
        XCTAssertFalse(InstallMode.silent.usesCustomTipRuntime)
        XCTAssertTrue(InstallMode.customTip.usesCustomTipRuntime)
        XCTAssertTrue(InstallMode.preserveWithTip.usesCustomTipRuntime)
        XCTAssertFalse(InstallMode.updateOnly.usesCustomTipRuntime)
    }
}
