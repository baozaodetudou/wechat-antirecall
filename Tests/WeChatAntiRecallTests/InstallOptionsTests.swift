import XCTest
@testable import WeChatAntiRecall

final class InstallOptionsTests: XCTestCase {
    func testStandaloneWithTipIsMarkedExplicit() throws {
        let options = try InstallOptions(["--with-tip"])
        XCTAssertTrue(options.withTip)
        XCTAssertTrue(options.explicitWithTip)
        XCTAssertFalse(options.runtimeTip)
        // The deprecation notice fires exactly when the user opted into standalone
        // --with-tip: explicitWithTip && !runtimeTip.
        XCTAssertTrue(options.explicitWithTip && !options.runtimeTip)
        // Lock the actual selection mechanism, not just the flag: --with-tip must still
        // resolve the revoke-tip byte patch instead of the silent revoke patch.
        XCTAssertTrue(options.targetIdentifiers.contains("revoke-tip"))
        XCTAssertFalse(options.targetIdentifiers.contains("revoke"))
    }

    func testRuntimeTipImpliesWithTipButIsNotExplicit() throws {
        let options = try InstallOptions(["--runtime-tip"])
        XCTAssertTrue(options.runtimeTip)
        XCTAssertTrue(options.withTip, "runtime-tip must still pull in the revoke-tip byte patch")
        XCTAssertFalse(options.explicitWithTip)
        // Users already on the recommended path are not nagged.
        XCTAssertFalse(options.explicitWithTip && !options.runtimeTip)
        // The IMPORTANT INVARIANT — runtime-tip depends on the revoke-tip target — is
        // asserted on the resolved targets, not merely the withTip boolean.
        XCTAssertTrue(options.targetIdentifiers.contains("revoke-tip"))
        XCTAssertTrue(options.targetIdentifiers.contains("runtime-tip"))
        XCTAssertFalse(options.targetIdentifiers.contains("revoke"))
    }

    func testRuntimeDylibImpliesRuntimeTipWithoutExplicitWithTip() throws {
        // --runtime-dylib is the other path that implies withTip; like --runtime-tip it
        // must never trigger the deprecation nag and must still pull in revoke-tip.
        let options = try InstallOptions(["--runtime-dylib", "/tmp/x.dylib"])
        XCTAssertTrue(options.runtimeTip)
        XCTAssertTrue(options.withTip)
        XCTAssertFalse(options.explicitWithTip)
        XCTAssertFalse(options.explicitWithTip && !options.runtimeTip)
        XCTAssertTrue(options.targetIdentifiers.contains("revoke-tip"))
    }

    func testWithTipCombinedWithRuntimeTipDoesNotTriggerNotice() throws {
        let options = try InstallOptions(["--with-tip", "--runtime-tip"])
        XCTAssertTrue(options.explicitWithTip)
        XCTAssertTrue(options.runtimeTip)
        // runtime-tip dominates, so no deprecation nag even though --with-tip was passed.
        XCTAssertFalse(options.explicitWithTip && !options.runtimeTip)
    }

    func testDefaultInstallIsSilentAndNotExplicitWithTip() throws {
        let options = try InstallOptions([])
        XCTAssertFalse(options.withTip)
        XCTAssertFalse(options.explicitWithTip)
        XCTAssertFalse(options.runtimeTip)
    }

    func testPreserveWithTipUsesNativeNoticeBranchAndAddsRowProtectionHook() throws {
        let options = try InstallOptions([
            "--preserve-with-tip",
            "--runtime-dylib", "/tmp/x.dylib",
        ])

        XCTAssertTrue(options.preserveWithTip)
        XCTAssertTrue(options.runtimeTip)
        XCTAssertTrue(options.withTip, "combined mode needs WeChat's native notice-producing branch")
        XCTAssertEqual(
            options.targetIdentifiers,
            ["revoke-tip", "runtime-tip", "runtime-preserve-tip"]
        )
    }

    func testPreserveWithTipIsRejectedWithStandaloneWithTip() throws {
        XCTAssertThrowsError(try InstallOptions(["--preserve-with-tip", "--with-tip"]))
    }

    func testDeprecationNoticeRecommendsRuntimeTipOnSupportedBuild() {
        let notice = withTipDeprecationNotice(buildVersion: "268850", runtimeTipSupported: true)
        XCTAssertTrue(notice.contains("已弃用"))
        XCTAssertTrue(notice.contains("建议改用 --runtime-tip"))
        // The justification is a capability claim (handled via the hook), not an unverified
        // outcome claim ("only it correctly handles ...").
        XCTAssertTrue(notice.contains("运行时 hook 处理"))
        XCTAssertFalse(notice.contains("只有它能正确处理"))
    }

    func testDeprecationNoticeFallsBackOnBuildWithoutRuntimeTip() {
        let notice = withTipDeprecationNotice(buildVersion: "268596", runtimeTipSupported: false)
        XCTAssertTrue(notice.contains("已弃用"))
        XCTAssertTrue(notice.contains("268596"))
        XCTAssertTrue(notice.contains("后备"))
        // On unsupported builds we must NOT recommend switching to a mode they can't use.
        XCTAssertFalse(notice.contains("建议改用 --runtime-tip"))
    }
}
