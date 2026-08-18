# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::Flow::Delete, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }
  let_it_be_with_reload(:flow) { create(:ai_catalog_flow, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_flow_delete, params) }
  let(:params) do
    {
      id: flow.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not delete the catalog item' do
      expect { execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when user has a custom role with admin_ai_catalog_item' do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) { create(:member_role, :guest, :admin_ai_catalog_item, namespace: project.group) }
    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: project)
    end

    let(:current_user) { custom_role_user }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'deletes the flow' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
    end
  end

  context 'when the flow does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy service fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::Flows::DestroyService) do |service|
        allow(service).to receive(:item).and_return(flow)
      end
      allow(flow).to receive(:destroy).and_return(false)
      flow.errors.add(:base, 'Deletion failed')
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_flow_delete, :errors)).to contain_exactly('Deletion failed')
      expect(graphql_data_at(:ai_catalog_flow_delete, :success)).to be(false)
    end
  end

  context 'when destroy service succeeds' do
    it 'destroy the flow and returns a success response' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
      expect(graphql_data_at(:ai_catalog_flow_delete, :success)).to be(true)
    end

    it 'destroy the flow versions' do
      expect { execute }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
    end

    context 'with `forceHardDelete` argument', :enable_admin_mode do
      let(:params) { super().merge(force_hard_delete: true) }

      it_behaves_like 'a mutation that returns top-level errors', errors:
        ['You must be an instance admin to use forceHardDelete']

      it 'does not destroy the flow' do
        expect { execute }.not_to change { Ai::Catalog::Item.count }
      end

      context 'when user is an admin' do
        let(:current_user) { create(:admin) }

        it 'destroys the flow and returns a success response' do
          expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
          expect(graphql_data_at(:ai_catalog_flow_delete, :success)).to be(true)
        end
      end
    end
  end
end
