# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemConsumer::Update, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: maintainer) }
  let_it_be(:project) { create(:project, group: group, maintainers: maintainer) }
  let_it_be(:item_project) { create(:project, maintainers: maintainer) }
  let_it_be_with_reload(:item_consumer) { create(:ai_catalog_item_consumer, project: project) }
  let_it_be_with_reload(:group_item_consumer) { create(:ai_catalog_item_consumer, group: group) }
  let_it_be_with_reload(:latest_version) do
    create(:ai_catalog_item_version, :released, item: item_consumer.item, project: item_project)
  end

  let_it_be_with_reload(:group_latest_version) do
    create(:ai_catalog_item_version, :released, item: group_item_consumer.item)
  end

  let(:current_user) { maintainer }
  let(:mutation) do
    graphql_mutation(:ai_catalog_item_consumer_update, params) do
      <<~MUTATION
      errors
      itemConsumer {
        id
        pinnedVersionPrefix
      }
      MUTATION
    end
  end

  let(:mutation_response) { graphql_data_at(:ai_catalog_item_consumer_update) }
  let(:params) do
    {
      id: item_consumer.to_global_id,
      pinned_version_prefix: latest_version.version
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the item consumer' do
      expect { execute }.not_to change { item_consumer.reload.attributes }
    end
  end

  context 'when user is a developer' do
    let(:current_user) { create(:user).tap { |user| project.add_developer(user) } }

    it_behaves_like 'an authorization failure'
  end

  describe 'group-level item consumer' do
    let(:params) do
      {
        id: group_item_consumer.to_global_id,
        pinned_version_prefix: group_latest_version.version
      }
    end

    context 'when user is a developer of the group' do
      let(:current_user) { create(:user).tap { |user| group.add_developer(user) } }

      it_behaves_like 'an authorization failure'
      it 'does not update the group item consumer' do
        expect { execute }.not_to change { group_item_consumer.reload.attributes }
      end
    end

    context 'when user is a maintainer on the group' do
      it 'returns a success response' do
        expect { execute }
          .to change { group_item_consumer.reload.pinned_version_prefix }.to(group_latest_version.version)

        expect(graphql_dig_at(mutation_response, :errors)).to be_empty
        expect(graphql_dig_at(mutation_response, :item_consumer)).to match(
          a_graphql_entity_for(group_item_consumer, :pinned_version_prefix)
        )
      end
    end
  end

  context 'when the item consumer does not exist' do
    let(:params) do
      super().merge(
        id: Gitlab::GlobalId.build(model_name: 'Ai::Catalog::ItemConsumer', id: non_existing_record_id)
      )
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when the pinnedVersionPrefix is not a valid version format' do
    let(:params) { super().merge(pinned_version_prefix: '1.1') }

    it_behaves_like 'a mutation that returns top-level errors', errors: [/is not a valid pinned version/]
  end

  context 'when item consumer update fails' do
    before do
      allow_next_instance_of(::Ai::Catalog::ItemConsumers::UpdateService) do |service|
        allow(service).to receive(:item_consumer).and_return(item_consumer)
      end

      allow(item_consumer).to receive(:update).and_return(false)
      item_consumer.errors.add(:base, 'Update failed')
    end

    it 'returns the service error message and item consumer with original attributes' do
      original_version = item_consumer.pinned_version_prefix

      execute

      expect(graphql_dig_at(mutation_response, :item_consumer, :pinned_version_prefix)).to eq(original_version)
      expect(graphql_dig_at(mutation_response, :errors)).to contain_exactly("Update failed")
    end
  end

  context 'when update succeeds' do
    it 'returns a success response' do
      expect { execute }
        .to change { item_consumer.reload.pinned_version_prefix }.to(latest_version.version)

      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
      expect(graphql_dig_at(mutation_response, :item_consumer)).to match(
        a_graphql_entity_for(item_consumer, :pinned_version_prefix)
      )
    end
  end

  context 'when using the pinned_version argument' do
    let(:params) do
      {
        id: item_consumer.to_global_id,
        pinned_version: latest_version.version
      }
    end

    it 'updates the pinned_version_prefix on the record' do
      expect { execute }
        .to change { item_consumer.reload.pinned_version_prefix }.to(latest_version.version)

      expect(graphql_dig_at(mutation_response, :errors)).to be_empty
    end
  end

  context 'when both pinned_version and pinned_version_prefix are provided' do
    let(:params) do
      {
        id: item_consumer.to_global_id,
        pinned_version: latest_version.version,
        pinned_version_prefix: latest_version.version
      }
    end

    it 'returns a top-level validation error and does not update the record' do
      expect { execute }.not_to change { item_consumer.reload.pinned_version_prefix }

      expect(graphql_errors.pluck('message'))
        .to include("One and only one of [pinnedVersion, pinnedVersionPrefix] arguments is required.")
    end
  end

  context 'when neither pinned_version nor pinned_version_prefix is provided' do
    let(:params) do
      { id: item_consumer.to_global_id }
    end

    it 'returns a top-level validation error and does not update the record' do
      expect { execute }.not_to change { item_consumer.reload.pinned_version_prefix }

      expect(graphql_errors.pluck('message'))
        .to include("One and only one of [pinnedVersion, pinnedVersionPrefix] arguments is required.")
    end
  end
end
