# Serves the deep-link association files consumed by the Hotwire Native apps:
#   - Apple Universal Links / Handoff / shared web credentials (AASA)
#   - Android App Links (assetlinks.json)
# These are public, unauthenticated JSON endpoints.
class WellKnownController < ApplicationController
  APP_ID = "VTT2UAS7Q4.cr.fdo.grind".freeze
  ANDROID_PACKAGE = "cr.fdo.grind".freeze
  # First entry is the local debug keystore fingerprint (from `./gradlew
  # signingReport`) so App Links verify during development. Append the release /
  # Play App Signing SHA-256 fingerprint here before shipping to production.
  ANDROID_SHA256_FINGERPRINTS = [
    "4F:F1:F2:92:1E:02:60:46:19:F1:88:84:54:19:1C:2E:2A:1A:39:64:4D:70:4D:7C:B7:15:BD:E9:80:B6:6E:D6"
  ].freeze

  def aasa
    render json: {
      applinks: {
        apps: [],
        details: [
          { appID: APP_ID, paths: [ "/*" ] }
        ]
      },
      activitycontinuation: { apps: [ APP_ID ] },
      webcredentials: { apps: [ APP_ID ] }
    }
  end

  def assetlinks
    render json: [
      {
        relation: [ "delegate_permission/common.handle_all_urls" ],
        target: {
          namespace: "android_app",
          package_name: ANDROID_PACKAGE,
          sha256_cert_fingerprints: ANDROID_SHA256_FINGERPRINTS
        }
      }
    ]
  end
end
