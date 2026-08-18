# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::ResolveServiceAccountService, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax
  include Ai::Catalog::TestHelpers

  subject(:result) { described_class.new(container: container, item: item).execute }

  describe '#execute' do
    let_it_be(:developer) { create(:user) }
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:owner) { create(:user) }
    let_it_be(:item) { create(:ai_catalog_flow) }

    let_it_be(:group) do
      create(:group, developers: developer, maintainers: maintainer, owners: owner)
    end

    let_it_be(:subgroup) do
      create(:group, developers: developer, maintainers: maintainer, owners: owner, parent: group)
    end

    let_it_be(:service_account) do
      create(:user, :service_account) do |user|
        create(:user_detail, user: user, provisioned_by_group: group)
      end
    end

    let_it_be(:group_project) do
      create(:project, developers: service_account, group: group)
    end

    let_it_be(:subgroup_project) do
      create(:project, developers: service_account, group: subgroup)
    end

    shared_examples 'no consumer found for container' do
      context 'when no consumers are found' do
        it 'returns an error', :aggregate_failures do
          expect(result).to be_error
          expect(result.message).to eq('No item consumer found for the root namespace.')
        end
      end
    end

    shared_examples 'no service account found for container' do
      context 'when no service account is found' do
        before do
          create_item_consumer(group, service_account).update!(service_account: nil)
        end

        it 'returns an error', :aggregate_failures do
          expect(result).to be_error
          expect(result.message).to eq('Could not find a valid service account for this agent/flow.')
        end
      end
    end

    shared_examples 'resolves service account for container' do
      context 'when service account is found' do
        before do
          parent = create_item_consumer(group, service_account)
          create_item_consumer(container, nil, parent_item_consumer: parent) if container.is_a?(Project)
        end

        it 'resolves the service account for the container' do
          expect(result).to be_success
          expect(result.payload[:service_account]).to eq(service_account)
        end
      end
    end

    context 'when container is a top-level group' do
      let(:container) { group }

      include_examples 'no consumer found for container'
      include_examples 'no service account found for container'
      include_examples 'resolves service account for container'
    end

    context 'when container is a subgroup' do
      let(:container) { subgroup }

      include_examples 'no consumer found for container'
      include_examples 'no service account found for container'
      include_examples 'resolves service account for container'
    end

    context 'when container is a project in the top-level group' do
      let(:container) { group_project }

      include_examples 'no consumer found for container'
      include_examples 'no service account found for container'
      include_examples 'resolves service account for container'
    end

    context 'when container is a project in the subgroup' do
      let(:container) { subgroup_project }

      include_examples 'no consumer found for container'
      include_examples 'no service account found for container'
      include_examples 'resolves service account for container'
    end
  end

  private

  def create_item_consumer(container, service_account, attributes = {})
    create(
      :ai_catalog_item_consumer,
      attributes.reverse_merge(
        item: item,
        project: container.is_a?(::Project) ? container : nil,
        group: container.is_a?(::Group) ? container : nil,
        service_account: service_account
      )
    )
  end
end
