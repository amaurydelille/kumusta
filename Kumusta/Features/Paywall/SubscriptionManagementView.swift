import SwiftUI
import RevenueCatUI

/// RevenueCat's Customer Center: plan details, plan changes, cancellation and
/// refund requests, configured in the RevenueCat dashboard. Restores made here
/// are reported back so Kumusta can refresh premium access.
struct SubscriptionManagementView: View {
    @Environment(DependencyContainer.self) private var dependencies

    let onRestoreCompleted: (Bool) -> Void

    var body: some View {
        CustomerCenterView()
            .onCustomerCenterRestoreStarted {
                dependencies.analytics.track(.restoreStarted, properties: ["source": "customer_center"])
            }
            .onCustomerCenterRestoreCompleted { customerInfo in
                let active = customerInfo.entitlements[dependencies.configuration.entitlementID]?.isActive == true
                dependencies.analytics.track(.restoreCompleted, properties: ["entitlement_found": String(active), "source": "customer_center"])
                onRestoreCompleted(active)
            }
            .onCustomerCenterRestoreFailed { _ in
                dependencies.analytics.track(.restoreFailed, properties: ["error_category": "sdk_error", "source": "customer_center"])
            }
    }
}
