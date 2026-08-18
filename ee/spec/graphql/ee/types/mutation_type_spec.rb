# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MutationType, feature_category: :api do
  describe 'deprecated mutations' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name, :reason, :milestone) do
      'ApiFuzzingCiConfigurationCreate' | 'The configuration snippet is now generated client-side' | '15.1'
    end

    with_them do
      let(:field) { get_field(field_name) }
      let(:deprecation_reason) { "#{reason}. Deprecated in #{milestone}." }

      it { expect(field).not_to be_present }
    end
  end

  def get_field(name)
    described_class.fields[GraphqlHelpers.fieldnamerize(name)]
  end

  describe '.authorization' do
    it 'allows ai_features and ai_workflows scope token' do
      expect(described_class.authorization.permitted_scopes).to include(:ai_features, :ai_workflows)
    end
  end

  describe 'ASCP mutation scopes' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name) do
      [
        ['ascpScanCreate'],
        ['ascpComponentCreate'],
        ['ascpSecurityContextCreate']
      ]
    end

    with_them do
      it 'includes api and ai_workflows scopes' do
        mutation = described_class.fields[field_name]
        expect(mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
      end
    end
  end

  describe 'vulnerability mutation scopes' do
    using RSpec::Parameterized::TableSyntax

    where(:field_name) do
      [
        ['vulnerabilityRevertToDetected'],
        ['vulnerabilityDismiss'],
        ['vulnerabilityConfirm'],
        ['vulnerabilitiesSeverityOverride'],
        ['vulnerabilityIssueLinkCreate'],
        ['vulnerabilitiesCreateIssue'],
        ['startVulnerabilityWorkflow'],
        ['cancelVulnerabilityWorkflow']
      ]
    end

    with_them do
      it 'includes api and ai_workflows scopes' do
        mutation = described_class.fields[field_name]
        expect(mutation.instance_variable_get(:@scopes)).to match_array([:api, :ai_workflows])
      end
    end
  end
end
