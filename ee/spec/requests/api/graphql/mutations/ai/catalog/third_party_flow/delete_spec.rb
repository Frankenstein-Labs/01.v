# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ThirdPartyFlow::Delete, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }
  let_it_be_with_reload(:third_party_flow) { create(:ai_catalog_third_party_flow, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_third_party_flow_delete, params) }
  let(:params) do
    {
      id: third_party_flow.to_global_id
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

  context 'when the third_party_flow does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::Item', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy service fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::ThirdPartyFlows::DestroyService) do |service|
        allow(service).to receive(:item).and_return(third_party_flow)
      end
      allow(third_party_flow).to receive(:destroy).and_return(false)
      third_party_flow.errors.add(:base, 'Deletion failed')
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_third_party_flow_delete, :errors)).to contain_exactly('Deletion failed')
      expect(graphql_data_at(:ai_catalog_third_party_flow_delete, :success)).to be(false)
    end
  end

  context 'when destroy service succeeds' do
    it 'destroy the third_party_flow and returns a success response' do
      expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
      expect(graphql_data_at(:ai_catalog_third_party_flow_delete, :success)).to be(true)
    end

    it 'destroy the third_party_flow versions' do
      expect { execute }.to change { Ai::Catalog::ItemVersion.count }.by(-1)
    end

    context 'with `forceHardDelete` argument', :enable_admin_mode do
      let(:params) { super().merge(force_hard_delete: true) }

      it_behaves_like 'a mutation that returns top-level errors', errors:
        ['You must be an instance admin to use forceHardDelete']

      it 'does not delete the third_party_flow' do
        expect { execute }.not_to change { Ai::Catalog::Item.count }
      end

      context 'when user is an admin' do
        let(:current_user) { create(:admin) }

        it 'destroys the third_party_flow and returns a success response' do
          expect { execute }.to change { Ai::Catalog::Item.count }.by(-1)
          expect(graphql_data_at(:ai_catalog_third_party_flow_delete, :success)).to be(true)
        end
      end
    end
  end
end
