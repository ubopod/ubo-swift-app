//
//  WatchIconFontBootstrap.swift
//  ubo Watch App
//
//  watchOS counterpart to `UboIconFontBootstrap`. Same logic — log
//  what's in the bundle, log Arimo-family availability, force-
//  register via CoreText if needed.
//

import Foundation
import CoreText
import SwiftUI
import UboSwift

public enum UboIconFontBootstrap {
    public static let resourceName = "ArimoNerdFont-Regular"
    public static let resourceExtension = "ttf"

    public static func ensureRegistered() {
        UboLog.input.info("UboIconFontBootstrap[watch]: starting registration")

        let bundle = Bundle.main

        if let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) {
            UboLog.input.info("UboIconFontBootstrap[watch]: TTF found at \(url.path)")
        } else {
            UboLog.input.error(
                "UboIconFontBootstrap[watch]: TTF NOT found in main bundle "
                + "(looking for \(resourceName).\(resourceExtension)). "
                + "Bundle path = \(bundle.bundlePath)"
            )
        }

        let preFamilies = matchingArimoFamilies()
        UboLog.input.info("UboIconFontBootstrap[watch] [before]: matching families = \(preFamilies)")

        if preFamilies.contains(UboIconFont.family) {
            UboLog.input.info("UboIconFontBootstrap[watch]: '\(UboIconFont.family)' already available; skipping manual register")
            return
        }

        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            UboLog.input.error("UboIconFontBootstrap[watch]: aborting — no resource URL")
            return
        }

        var registerError: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &registerError)
        if registered {
            UboLog.input.info("UboIconFontBootstrap[watch]: CTFontManagerRegisterFontsForURL succeeded")
        } else {
            let err = registerError?.takeRetainedValue()
            UboLog.input.error("UboIconFontBootstrap[watch]: registration failed: \(String(describing: err))")
        }

        let postFamilies = matchingArimoFamilies()
        UboLog.input.info("UboIconFontBootstrap[watch] [after]: matching families = \(postFamilies)")

        if !postFamilies.contains(UboIconFont.family) {
            UboLog.input.error(
                "UboIconFontBootstrap[watch]: '\(UboIconFont.family)' STILL not resolvable. "
                + "Check 'after' family list above."
            )
        }
    }

    private static func matchingArimoFamilies() -> [String] {
        let families = (CTFontManagerCopyAvailableFontFamilyNames() as? [String]) ?? []
        return families.filter {
            let lower = $0.lowercased()
            return lower.contains("arimo") || lower.contains("nerd")
        }
    }
}
