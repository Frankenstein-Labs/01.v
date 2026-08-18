# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiSelfHostedModelReleaseState'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiSelfHostedModelReleaseState') }

  describe 'self-hosted model release state' do
    using RSpec::Parameterized::TableSyntax

    where(:release_state_name, :release_state_value) do
      'EXPERIMENTAL' | 'experimental'
      'BETA'         | 'beta'
      'GA'           | 'ga'
    end

    with_them do
      it 'exposes the release state with the correct value' do
        expect(described_class.values[release_state_name].value).to eq(release_state_value)
      end
    end
  end
end
