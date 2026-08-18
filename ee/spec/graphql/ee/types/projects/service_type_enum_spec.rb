# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ServiceType'], feature_category: :system_access do
  it 'includes services that are blocked by settings' do
    stub_application_setting(allow_all_integrations: false)
    stub_licensed_features(integrations_allow_list: true)

    # As the enum values have been set when the class loaded, before the settings
    # were stubbed above, test indirectly by comparing with `.integration_names`.
    types = described_class.send(:integration_names).map do |name|
      Integration.integration_name_to_type(name)
    end

    expect(types).to match_array(described_class.values.values.map(&:value))
    expect(Integrations::Asana).to be_blocked_by_settings
    expect(types).to include('Integrations::Asana')
  end

  it 'includes all SaaS-only integrations in SASS_ONLY_INTEGRATION_NAMES' do
    non_sass_integrations = Integration.all_integration_names

    allow(Gitlab).to receive(:com?).and_return(true)

    sass_only_integrations = Integration.all_integration_names - non_sass_integrations

    expect(sass_only_integrations).not_to be_empty
    expect(sass_only_integrations).to match_array(described_class::SAAS_ONLY_INTEGRATION_NAMES)
  end

  # We test the description behavior indirectly through the (private) #value_description
  # as using `:sass` to stub `GitLab.com?` is too late because the class has loaded at that point
  # and dynamically set its enum values.
  describe '#value_description (private)' do
    it 'describes SaaS-only integrations as (SaaS only)' do
      descriptions = described_class::SAAS_ONLY_INTEGRATION_NAMES.map do |name|
        described_class.send(:value_description, name)
      end

      expect(descriptions).to all(end_with('(SaaS only)'))
    end

    it 'does not describe other integrations as (SaaS only)' do
      expect(described_class.send(:value_description, 'asana')).not_to end_with('(SaaS only)')
    end
  end
end
