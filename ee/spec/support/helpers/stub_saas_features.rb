# frozen_string_literal: true

module StubSaasFeatures
  @features_stubbed = false

  class << self
    attr_accessor :features_stubbed
  end

  # Stub SaaS feature with `feature_name: true/false`
  #
  # @param [Hash] features where key is feature name and value is boolean whether enabled or not.
  #
  # This should only ever be called from ee code as it enforces the following of the
  # https://docs.gitlab.com/ee/development/ee_features.html guidelines in the test area.
  # `Gitlab::Saas::FEATURES` is only defined in ee, which helps drive the logic in that proper division of
  # testing.
  #
  # Examples
  # - `stub_saas_features(onboarding: false)` ... Disable `onboarding`
  #   SaaS feature globally.
  # - `stub_saas_features(onboarding: true)` ... Enable `onboarding`
  #   SaaS feature globally.
  def stub_saas_features(features)
    all_features = ::Gitlab::Saas::FEATURES.index_with { |feature| ::Gitlab::Saas.feature_available?(feature) }
    all_features.merge!(features)

    all_features.each do |feature_name, value|
      raise ArgumentError, 'value must be boolean' unless value.in? [true, false]

      allow(::Gitlab::Saas).to receive(:feature_available?).with(feature_name).and_return(value)
    end
  end
end
