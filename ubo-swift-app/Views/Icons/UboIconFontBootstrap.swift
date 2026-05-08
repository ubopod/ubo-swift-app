//
//  UboIconFontBootstrap.swift
//  ubo-swift-app
//
//  Bundles the Nerd Font and ensures it's registered with the
//  font manager. Synchronized Xcode projects + INFOPLIST_KEY_UIAppFonts
//  *should* register it automatically, but Xcode sometimes drops the
//  resource silently. This bootstrap logs every step so we can see in
//  Console.app exactly why an icon isn't rendering, and force-
//  registers the TTF via CoreText if iOS hasn't done so already.
//

import Foundation
import CoreText
#if os(iOS)
import UIKit
#endif
import UboSwift

public enum UboIconFontBootstrap {
    /// Filename of the bundled Nerd Font TTF.
    public static let resourceName = "ArimoNerdFont-Regular"
    public static let resourceExtension = "ttf"

    /// Call once during app launch (e.g. from `App.init`) so font
    /// registration happens before the first icon view is rendered.
    public static func ensureRegistered() {
        UboLog.input.info("UboIconFontBootstrap: starting registration")

        let bundle = Bundle.main

        // Step 1 — what does the bundle think it has?
        if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
            UboLog.input.info("UboIconFontBootstrap: TTF found at \(url.path)")
        } else {
            UboLog.input.error(
                "UboIconFontBootstrap: TTF NOT found in main bundle "
                + "(looking for \(resourceName).\(resourceExtension)). "
                + "Bundle path = \(bundle.bundlePath)"
            )
        }

        // Step 2 — what does iOS know about Arimo right now?
        logArimoFonts(stage: "before registration")

        // Step 3 — does the family already resolve?
        if isFamilyAvailable(UboIconFont.family) {
            UboLog.input.info("UboIconFontBootstrap: '\(UboIconFont.family)' already available; skipping manual register")
            return
        }

        // Step 4 — manual register from the bundle URL.
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            UboLog.input.error("UboIconFontBootstrap: aborting — no resource URL")
            return
        }

        var registerError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registerError)
        if registered {
            UboLog.input.info("UboIconFontBootstrap: CTFontManagerRegisterFontsForURL succeeded")
        } else {
            let err = registerError?.takeRetainedValue()
            UboLog.input.error("UboIconFontBootstrap: registration failed: \(String(describing: err))")
        }

        logArimoFonts(stage: "after registration")

        if isFamilyAvailable(UboIconFont.family) {
            UboLog.input.info("UboIconFontBootstrap: '\(UboIconFont.family)' is now available")
        } else {
            UboLog.input.error(
                "UboIconFontBootstrap: '\(UboIconFont.family)' STILL not resolvable. "
                + "Check the family name printed under 'after registration'."
            )
        }
    }

    private static func logArimoFonts(stage: String) {
        #if os(iOS)
        let families = UIFont.familyNames
        let arimo = families.filter { $0.lowercased().contains("arimo") || $0.lowercased().contains("nerd") }
        UboLog.input.info("UboIconFontBootstrap [\(stage)]: matching families = \(arimo)")
        for family in arimo {
            let names = UIFont.fontNames(forFamilyName: family)
            UboLog.input.info("UboIconFontBootstrap [\(stage)]:   '\(family)' -> \(names)")
        }
        #else
        let descriptors = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
        let arimo = descriptors.filter { $0.lowercased().contains("arimo") || $0.lowercased().contains("nerd") }
        UboLog.input.info("UboIconFontBootstrap [\(stage)]: matching families = \(arimo)")
        #endif
    }

    private static func isFamilyAvailable(_ name: String) -> Bool {
        #if os(iOS)
        return UIFont.familyNames.contains(name)
            || UIFont.fontNames(forFamilyName: name).isEmpty == false
        #else
        let families = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
        return families.contains(name)
        #endif
    }
}
