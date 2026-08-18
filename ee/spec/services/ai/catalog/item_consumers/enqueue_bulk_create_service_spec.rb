# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::EnqueueBulkCreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, owners: current_user) }
  let_it_be(:project_1) { create(:project, group: group, maintainers: current_user) }
  let_it_be(:project_2) { create(:project, group: group, maintainers: current_user) }
  let_it_be(:project_in_different_group) { create(:project, maintainers: current_user) }
  let_it_be(:item) { create(:ai_catalog_agent, :with_released_version, :public) }

  let(:trigger_types) { nil }
  let(:trigger_filter) { nil }
  let(:pinned_version) { nil }
  let(:project_ids) { [project_1.to_global_id.to_s, project_2.to_global_id.to_s] }

  subject(:execute) do
    described_class.new(current_user:, item:, project_ids:, trigger_types:, trigger_filter:,
      pinned_version:).execute
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'returns a permission error' do
    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to include(
        'One or more projects not found, or you do not have permission to enable this item in the project.'
      )
    end
  end

  it 'creates item consumers for each project and parent group', :sidekiq_inline do
    expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

    expect(execute).to be_success
    expect(Ai::Catalog::ItemConsumer.exists?(group: group, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_1, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_2, ai_catalog_item_id: item.id)).to be true
  end

  # We have to reset the Redis data, otherwise de-duplication logic will kick in and prevent the job from being
  # enqueued, if it was enqueued already in a previous spec.
  it "enqueues the worker with the item's organization in the context", :clean_gitlab_redis_queues_metadata do
    expect(execute).to be_success

    job = ::Ai::Catalog::ItemConsumers::BulkCreateWorker.jobs.last
    expect(job['meta.organization_id']).to eq(item.organization_id)
  end

  it 'introduces only known N+1 queries' do
    execute = ->(project_ids) {
      described_class.new(current_user:, item:, project_ids:).execute
    }

    # Warm up
    execute.call([project_1.to_global_id.to_s, project_2.to_global_id.to_s])

    control = ActiveRecord::QueryRecorder.new do
      result = execute.call([project_1.to_global_id.to_s, project_2.to_global_id.to_s])

      expect(result).to be_success
    end

    # Threshold of 1 needed because CascadingProjectSettingAttribute.locked_ancestor queries all ancestors
    # for each project for the `duo_features_enabled_locked?` check in the project policy.
    expect do
      result = execute.call(
        [project_1.to_global_id.to_s, project_2.to_global_id.to_s, project_in_different_group.to_global_id.to_s]
      )

      expect(result).to be_success
    end.not_to exceed_query_limit(control).with_threshold(1)
  end

  context 'when item is foundational' do
    let_it_be(:item) { create(:ai_catalog_agent, :public) }

    before do
      allow(item).to receive(:foundational?).and_return(true)
    end

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to include(
        'Foundational agents and flows must be enabled in the Admin area or group settings.'
      )
    end
  end

  context 'when item is a foundational third_party_flow' do
    let_it_be(:item) do
      create(:ai_catalog_third_party_flow, :with_released_version, :public, verification_level: :gitlab_maintained)
    end

    let(:trigger_types) { %w[mention] }

    it 'is allowed' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async)

      expect(execute).to be_success
    end
  end

  context 'when trigger_types are provided for an agent' do
    let(:trigger_types) { %w[mention] }

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to include('Trigger types are not supported for this item type.')
    end
  end

  context 'when trigger_types are missing for a flow' do
    let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, :public) }
    let(:trigger_types) { nil }

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to include('Trigger types are required for flows.')
    end
  end

  context 'when trigger_filter is provided for an agent' do
    let(:trigger_filter) { { 'mention' => { 'field' => 'value' } } }

    it 'returns an error' do
      expect(execute).to be_error
      expect(execute.message).to include('Trigger filters are not supported for this item type.')
    end
  end

  context 'when project_ids contain duplicates' do
    let(:project_ids) { [project_1.to_global_id.to_s, project_1.to_global_id.to_s] }

    it 'deduplicates and succeeds' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
        current_user.id,
        item.id,
        [project_1.id],
        {}
      )

      expect(execute).to be_success
    end
  end

  context 'when trigger_types and trigger_filter are provided for a flow' do
    let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, :public) }

    let(:trigger_types) { %w[mention] }
    let(:trigger_filter) { { 'mention' => { 'field' => 'value' } } }

    it 'enqueues the worker with trigger_types and trigger_filter', :aggregate_failures do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
        current_user.id,
        item.id,
        contain_exactly(project_1.id, project_2.id),
        { 'trigger_types' => trigger_types, 'trigger_filter' => trigger_filter }
      )

      expect(execute).to be_success
    end
  end

  context 'when pinned_version is provided' do
    let(:pinned_version) { '1.2.3' }

    before do
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '1.2.3')
    end

    it 'enqueues the worker with pinned_version', :aggregate_failures do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).to receive(:perform_async).with(
        current_user.id,
        item.id,
        contain_exactly(project_1.id, project_2.id),
        { 'pinned_version' => '1.2.3' }
      )

      expect(execute).to be_success
    end

    shared_examples 'returns a version error' do
      it 'returns an error and does not enqueue the worker', :aggregate_failures do
        expect(::Ai::Catalog::ItemConsumers::BulkCreateWorker).not_to receive(:perform_async)

        expect(execute).to be_error
        expect(execute.message).to include(
          'Pinned version must resolve to a released version of the agent or flow.'
        )
      end
    end

    context 'when the version is not released' do
      let(:pinned_version) { '2.2.2' }

      before do
        create(:ai_catalog_agent_version, :draft, item: item.class.find(item.id), version: '2.2.2')
      end

      it_behaves_like 'returns a version error'
    end

    context 'when the version does not exist' do
      let(:pinned_version) { '9.9.9' }

      # Swallow the dev exception Item#resolve_version raises for unknown versions.
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it_behaves_like 'returns a version error'
    end
  end

  context 'when a project does not exist' do
    let(:project_ids) { [project_1.to_global_id.to_s, "gid://gitlab/Project/#{non_existing_record_id}"] }

    it_behaves_like 'returns a permission error'
  end

  context 'when user is not authorized for one of the projects' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:unauthorized_project) { create(:project, group: other_group) }

    let(:project_ids) { [project_1.to_global_id.to_s, unauthorized_project.to_global_id.to_s] }

    it_behaves_like 'returns a permission error'
  end

  context 'when a project belongs to a different organization than the item' do
    let_it_be(:other_organization) { create(:organization) }

    let_it_be(:other_org_project) do
      create(:project, :in_group, organization: other_organization, maintainers: current_user)
    end

    let(:project_ids) { [project_1.to_global_id.to_s, other_org_project.to_global_id.to_s] }

    it 'returns an organization mismatch error' do
      expect(execute).to be_error
      expect(execute.message).to include('All projects must belong to the same organization as the agent or flow.')
    end
  end

  context 'when user lacks item-type-specific permission' do
    context 'when item is an agent' do
      let_it_be(:item) { create(:ai_catalog_agent, :with_released_version, :public) }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(current_user, :create_ai_catalog_agent_item_consumer,
          anything).and_return(false)
      end

      it_behaves_like 'returns a permission error'
    end

    context 'when item is a non-foundational flow' do
      let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, :public) }

      let(:trigger_types) { %w[mention] }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(current_user, :create_ai_catalog_flow_item_consumer,
          anything).and_return(false)
      end

      it_behaves_like 'returns a permission error'
    end

    context 'when item is a third-party flow' do
      let_it_be(:item) { create(:ai_catalog_third_party_flow, :with_released_version, :public) }

      let(:trigger_types) { %w[mention] }

      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(current_user, :create_ai_catalog_third_party_flow_item_consumer,
          anything).and_return(false)
      end

      it_behaves_like 'returns a permission error'
    end

    context 'when item type does not match any known type' do
      before do
        allow(item).to receive_messages(agent?: false, flow?: false, third_party_flow?: false)
      end

      it 'raises an ArgumentError' do
        expect { execute }.to raise_error(ArgumentError, /Unsupported item type/)
      end
    end
  end
end
