# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    class OfflineCloudLicenseProvisionWorker
      include ::Gitlab::Utils::StrongMemoize
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Context unnecessary

      data_consistency :sticky
      feature_category :"add-on_provisioning"
      idempotent!

      def perform
        return unless license&.offline_cloud_license?

        log_event provision_add_on_purchases
      end

      private

      def license
        License.current
      end
      strong_memoize_attr :license

      def provision_add_on_purchases
        ::GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::AddOns.new.execute
      end

      def log_event(response)
        Gitlab::AppLogger.info(
          message: 'Offline license checked for potentially new add-on purchases',
          subscription_id: license.subscription_id,
          subscription_name: license.subscription_name,
          response: response.to_h
        )
      end
    end
  end
end
