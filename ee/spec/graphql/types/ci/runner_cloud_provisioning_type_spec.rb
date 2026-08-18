# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiRunnerCloudProvisioning'], feature_category: :runner_core do
  it 'returns all possible types' do
    expect(described_class.possible_types).to include(
      ::Types::Ci::RunnerGoogleCloudProvisioningType
    )
  end

  describe '#resolve_type' do
    using RSpec::Parameterized::TableSyntax

    where(:provider, :expected_type) do
      :google_cloud | ::Types::Ci::RunnerGoogleCloudProvisioningType
      :gke | ::Types::Ci::RunnerGkeProvisioningType
    end

    subject(:resolved_type) do
      described_class.resolve_type({ container: nil, provider: provider, cloud_project_id: 'some_project_id' }, {})
    end

    with_them do
      specify { expect(resolved_type).to eq(expected_type) }
    end

    context 'when provider is unknown' do
      let(:provider) { :unknown }

      it 'raises an error' do
        expect { resolved_type }.to raise_error(Types::Ci::RunnerCloudProvisioningType::UnexpectedProviderType)
      end
    end
  end
end
