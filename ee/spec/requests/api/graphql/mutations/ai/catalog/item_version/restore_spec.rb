# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::ItemVersion::Restore, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer, developers: developer) }
  let_it_be_with_reload(:item) { create(:ai_catalog_agent, project: project) }

  let_it_be(:version_1_0) do
    create(:ai_catalog_item_version, :released, item: item, version: '1.0.0')
  end

  let_it_be(:version_1_1) do
    create(:ai_catalog_item_version, :released, item: item, version: '1.1.0')
  end

  let(:current_user) { maintainer }
  let(:source_version) { version_1_0 }
  let(:deprecate_current) { false }
  let(:mutation) { graphql_mutation(:ai_catalog_item_version_restore, params) }
  let(:params) do
    {
      id: source_version.to_global_id.to_s,
      deprecate_current: deprecate_current
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    enable_ai_catalog
    item.update!(latest_released_version: version_1_1)
  end

  context 'when user is a developer' do
    let(:current_user) { developer }

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a new version' do
      expect { execute }.not_to change { Ai::Catalog::ItemVersion.count }
    end
  end

  context 'when version does not exist' do
    let(:params) do
      {
        id: "gid://gitlab/Ai::Catalog::ItemVersion/#{non_existing_record_id}",
        deprecate_current: deprecate_current
      }
    end

    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not create a new version' do
      expect { execute }.not_to change { Ai::Catalog::ItemVersion.count }
    end
  end

  context 'when feature flag is disabled' do
    before do
      stub_feature_flags(ai_catalog_version_restore: false)
    end

    it 'returns an error' do
      execute

      expect(graphql_data_at(:ai_catalog_item_version_restore, :errors))
        .to contain_exactly('This feature is not available.')
    end
  end

  context 'when user is a maintainer' do
    it_behaves_like 'authorizing granular token permissions for GraphQL', :restore_ai_catalog_item do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) { graphql_mutation(:ai_catalog_item_version_restore, params, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'creates a new version restored from the source' do
      expect { execute }.to change { Ai::Catalog::ItemVersion.count }.by(1)
    end

    it 'returns the newly created version', :aggregate_failures do
      execute

      expect(graphql_data_at(:ai_catalog_item_version_restore, :errors)).to be_empty
      expect(graphql_data_at(:ai_catalog_item_version_restore, :item_version, :version_name)).to eq('1.2.0')
      expect(graphql_data_at(:ai_catalog_item_version_restore, :item_version, :released)).to be(true)
      expect(graphql_data_at(:ai_catalog_item_version_restore, :item_version, :deprecated)).to be(false)
    end

    it 'does not deprecate the current latest version by default' do
      execute

      expect(version_1_1.reload.deprecated).to be(false)
    end

    context 'when deprecate_current is true' do
      let(:deprecate_current) { true }

      it 'deprecates the current latest version' do
        execute

        expect(version_1_1.reload.deprecated).to be(true)
      end
    end
  end
end
