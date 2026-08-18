# frozen_string_literal: true

RSpec.configure do |config|
  Gitlab::Saas::FEATURES.each do |feature|
    metadata = :"saas_#{feature}"

    config.before(:context, metadata) do
      StubSaasFeatures.features_stubbed = true
      # Mark that this was set at context level so we don't reset it in after(:each)
      @saas_features_context_level = true
    end

    config.after(:context, metadata) do
      StubSaasFeatures.features_stubbed = false
      @saas_features_context_level = false
    end

    config.before(:each, metadata) do
      # In case we only set this variable at the individual example level, we need this for
      # the factory creation for gitlab_subscription
      StubSaasFeatures.features_stubbed = true
      stub_saas_features(feature => true)
    end

    config.after(:each, metadata) do
      # Only reset if it wasn't set at the context level
      StubSaasFeatures.features_stubbed = false unless @saas_features_context_level
    end
  end
end
