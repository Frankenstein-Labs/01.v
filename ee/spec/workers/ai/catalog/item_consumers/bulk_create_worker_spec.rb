# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::BulkCreateWorker, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project_1) { create(:project, group: group, maintainers: user) }
  let_it_be(:project_2) { create(:project, group: group, maintainers: user) }
  let_it_be(:item) { create(:ai_catalog_agent, :with_released_version, :public) }

  let(:worker) { described_class.new }
  let(:params) { {} }

  let(:user_id) { user.id }
  let(:item_id) { item.id }
  let(:project_ids) { [project_1.id, project_2.id] }

  subject(:perform_worker) { worker.perform(user_id, item_id, project_ids, params) }

  before do
    enable_ai_catalog
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [user_id, item_id, project_ids, params] }

    it 'does not create more consumers on the second call' do
      expect { worker.perform(user_id, item_id, project_ids, params) }.to change { Ai::Catalog::ItemConsumer.count }

      expect { worker.perform(user_id, item_id, project_ids, params) }.not_to change { Ai::Catalog::ItemConsumer.count }
    end
  end

  it 'creates item consumers for each project' do
    expect { perform_worker }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

    expect(Ai::Catalog::ItemConsumer.exists?(group: group, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_1, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_2, ai_catalog_item_id: item.id)).to be true
  end

  it 'sends a result email' do
    expect { perform_worker }.to have_enqueued_mail(::Ai::Catalog::BulkItemConsumerMailer, :bulk_create_result_email)
  end

  context 'when trigger_types are provided' do
    let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, :public) }
    let_it_be(:item_id) { item.id }

    let(:params) { { 'trigger_types' => %w[mention] } }

    it 'creates item consumers with the correct triggers' do
      expect { perform_worker }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

      consumer = Ai::Catalog::ItemConsumer.find_by(project: project_1, ai_catalog_item_id: item.id)
      expect(consumer.flow_trigger.event_types).to contain_exactly(Ai::FlowTrigger::EVENT_TYPES[:mention])
    end
  end

  context 'when trigger_types and trigger_filter are provided' do
    let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, :public) }
    let_it_be(:item_id) { item.id }

    let(:trigger_filter) do
      {
        'pipeline_hooks' => {
          'rules' => [
            { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
          ]
        }
      }
    end

    let(:params) { { 'trigger_types' => %w[pipeline_hooks], 'trigger_filter' => trigger_filter } }

    it 'creates item consumers with the correct trigger filter', :aggregate_failures do
      expect { perform_worker }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

      consumer = Ai::Catalog::ItemConsumer.find_by(project: project_1, ai_catalog_item_id: item.id)
      expect(consumer.flow_trigger.filter).to eq(trigger_filter)
    end
  end

  context 'when pinned_version is provided' do
    let(:params) { { 'pinned_version' => '1.2.3' } }

    before do
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '1.2.3')
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '2.3.4')
    end

    it 'creates item consumers pinned to the specified version', :aggregate_failures do
      expect { perform_worker }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

      consumer = Ai::Catalog::ItemConsumer.find_by(project: project_1, ai_catalog_item_id: item.id)
      expect(consumer.pinned_version_prefix).to eq('1.2.3')
    end
  end

  context 'when user does not exist' do
    let(:user_id) { non_existing_record_id }

    it 'returns early without calling the service or sending email' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateService).not_to receive(:new)

      expect { perform_worker }
        .not_to have_enqueued_mail(::Ai::Catalog::BulkItemConsumerMailer, :bulk_create_result_email)
    end
  end

  context 'when item does not exist' do
    let(:item_id) { non_existing_record_id }

    it 'returns early without calling the service or sending email' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateService).not_to receive(:new)

      expect { perform_worker }
        .not_to have_enqueued_mail(::Ai::Catalog::BulkItemConsumerMailer, :bulk_create_result_email)
    end
  end

  context 'when item is soft deleted' do
    let_it_be(:deleted_item) { create(:ai_catalog_agent, :with_released_version, :soft_deleted, :public) }

    let(:item_id) { deleted_item.id }

    it 'returns early without calling the service' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateService).not_to receive(:new)

      perform_worker
    end
  end

  context 'when the ai_catalog_bulk_item_consumer_create flag is disabled' do
    before do
      stub_feature_flags(ai_catalog_bulk_item_consumer_create: false)
    end

    it 'returns early and does not process the projects' do
      expect { perform_worker }.not_to change { Ai::Catalog::ItemConsumer.count }
    end
  end

  context 'when no projects exist' do
    let(:project_ids) { [non_existing_record_id] }

    it 'returns early without calling the service or sending email' do
      expect(::Ai::Catalog::ItemConsumers::BulkCreateService).not_to receive(:new)

      expect { perform_worker }
        .not_to have_enqueued_mail(::Ai::Catalog::BulkItemConsumerMailer, :bulk_create_result_email)
    end
  end
end
