# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::OrganizationClusterAgentMapping, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:organization) { create(:organization) }
  let_it_be_with_reload(:agent) { create(:cluster_agent) }

  subject(:organization_cluster_agent_mapping) do
    create(
      :organization_cluster_agent_mapping,
      user: user,
      agent: agent,
      organization: organization
    )
  end

  describe 'associations' do
    context "for belongs_to" do
      it "belongs to user" do
        is_expected
          .to belong_to(:user)
                .class_name('User')
                .with_foreign_key(:creator_id)
                .inverse_of(:created_organization_cluster_agent_mappings)
      end

      it "belongs to organization" do
        is_expected
          .to belong_to(:organization)
                .inverse_of(:organization_cluster_agent_mappings)
      end

      it "belongs to agent" do
        is_expected
          .to belong_to(:agent)
                .class_name('Clusters::Agent')
                .with_foreign_key(:cluster_agent_id)
                .inverse_of(:organization_cluster_agent_mapping)
      end
    end

    context 'when from factory' do
      it 'has correct associations from factory' do
        expect(organization_cluster_agent_mapping.user).to eq(user)
        expect(organization_cluster_agent_mapping.agent).to eq(agent)
        expect(organization_cluster_agent_mapping.organization).to eq(organization)
      end
    end
  end
end
