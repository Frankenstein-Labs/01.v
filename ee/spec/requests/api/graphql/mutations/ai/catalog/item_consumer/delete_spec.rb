# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Delete, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }
  let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }

  let(:current_user) { maintainer }
  let(:mutation) { graphql_mutation(:ai_catalog_item_consumer_delete, params) }
  let(:params) do
    {
      id: item_consumer.to_global_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not delete the item consumer' do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  context 'when the item consumer does not exist' do
    let(:params) do
      {
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemConsumer', id: non_existing_record_id)
      }
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when destroy service fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::ItemConsumers::DestroyService) do |service|
        allow(service).to receive(:item_consumer).and_return(item_consumer)
      end

      allow(item_consumer).to receive(:destroy).and_return(false)
      item_consumer.errors.add(:base, 'Deletion failed')
    end

    it 'returns the service error message' do
      execute

      expect(graphql_data_at(:ai_catalog_item_consumer_delete, :errors)).to contain_exactly('Deletion failed')
      expect(graphql_data_at(:ai_catalog_item_consumer_delete, :success)).to be(false)
    end
  end

  context 'when user has a custom role with admin_ai_catalog_item_consumer' do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) do
      create(:member_role, :guest, :admin_ai_catalog_item_consumer, namespace: project.group)
    end

    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: project)
    end

    let(:current_user) { custom_role_user }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'destroys the item consumer' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
    end
  end

  context 'when destroy service succeeds' do
    it 'destroys the item consumer and returns a success response' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(-1)
      expect(graphql_data_at(:ai_catalog_item_consumer_delete, :success)).to be(true)
    end
  end
end
