# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CveEnrichmentType'], feature_category: :vulnerability_management do
  it { expect(described_class).to have_graphql_fields(:cve, :epss_score, :is_known_exploit) }

  describe '.authorization_scopes' do
    it 'includes :ai_workflows' do
      expect(described_class.authorization_scopes).to include(:ai_workflows)
    end
  end

  describe 'field scopes' do
    {
      'cve' => %i[api read_api ai_workflows],
      'epssScore' => %i[api read_api ai_workflows],
      'isKnownExploit' => %i[api read_api ai_workflows]
    }.each do |field, scopes|
      it "includes the correct scopes for #{field}" do
        expect(described_class.fields[field].instance_variable_get(:@scopes)).to include(*scopes)
      end
    end
  end
end
