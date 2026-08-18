# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemConsumers::BulkCreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, owners: current_user) }
  let_it_be(:project_1) { create(:project, group: group, maintainers: current_user) }
  let_it_be(:project_2) { create(:project, group: group, maintainers: current_user) }
  let_it_be(:item) { create(:ai_catalog_agent, :with_released_version, :public) }

  let(:projects) { Project.id_in([project_1.id, project_2.id]) }
  let(:trigger_types) { nil }
  let(:trigger_filter) { nil }
  let(:pinned_version) { nil }

  subject(:execute) do
    described_class.new(current_user:, item:, projects:, trigger_types:, trigger_filter:, pinned_version:).execute
  end

  before do
    enable_ai_catalog
  end

  shared_examples 'logs the failure' do
    it 'logs the failure' do
      mock_logger = Ai::Catalog::Logger.build
      allow(Ai::Catalog::Logger).to receive(:build).and_return(mock_logger)
      allow(mock_logger).to receive(:context).and_return(mock_logger)

      expect(mock_logger).to receive(:context).with(item:)
      expect(mock_logger).to receive(:error).with(
        message: 'Failed to create item consumer for project',
        project_id: failed_project.id,
        error_message: failure_message
      )

      execute
    end
  end

  it 'creates item consumers for each project and returns success' do
    expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(3)
      .and not_change { Ai::FlowTrigger.count }

    expect(Ai::Catalog::ItemConsumer.exists?(group: group, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_1, ai_catalog_item_id: item.id)).to be true
    expect(Ai::Catalog::ItemConsumer.exists?(project: project_2, ai_catalog_item_id: item.id)).to be true
    expect(execute).to be_success
    expect(execute.payload[:failures]).to be_empty
    expect(execute.payload[:successful_count]).to eq(2)
  end

  context 'when trigger_types are provided for a flow item' do
    let(:item) { create(:ai_catalog_flow, :with_released_version, :public) }
    let(:trigger_types) { ['mention'] }

    it 'creates item consumers with flow triggers for each project' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
        .and change { Ai::FlowTrigger.count }.by(2)

      consumer = Ai::Catalog::ItemConsumer.last
      expect(consumer.flow_trigger.event_types).to contain_exactly(Ai::FlowTrigger::EVENT_TYPES[:mention])
    end

    context 'when trigger_filter is also provided' do
      let(:trigger_types) { %w[pipeline_hooks] }
      let(:trigger_filter) do
        {
          'pipeline_hooks' => {
            'rules' => [
              { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
            ]
          }
        }
      end

      it 'creates item consumers with the trigger filter for each project', :aggregate_failures do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
          .and change { Ai::FlowTrigger.count }.by(2)

        consumer = Ai::Catalog::ItemConsumer.find_by(project: project_1, ai_catalog_item_id: item.id)
        expect(consumer.flow_trigger.filter).to eq(trigger_filter)
      end
    end
  end

  context 'when pinned_version is provided' do
    let(:pinned_version) { '1.2.3' }

    before do
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '1.2.3')
      create(:ai_catalog_agent_version, :released, item: item.class.find(item.id), version: '2.3.4')
    end

    it 'creates item consumers pinned to the specified version', :aggregate_failures do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(3)

      [project_1, project_2].each do |project|
        consumer = Ai::Catalog::ItemConsumer.find_by(project: project, ai_catalog_item_id: item.id)
        expect(consumer.pinned_version_prefix).to eq('1.2.3')
      end
    end
  end

  context 'when a consumer fails to be created for a project' do
    let_it_be(:unauthorized_project) { create(:project, :in_group) }

    let(:projects) { Project.id_in([project_1.id, unauthorized_project.id]) }

    it 'tracks successes and failures in results', :aggregate_failures do
      expect(execute).to be_success
      expect(execute.payload[:successful_count]).to eq(1)
      expect(execute.payload[:failures]).to include(
        a_hash_including(
          project_id: unauthorized_project.id,
          error_message: "You don't have permission to enable this agent or flow, or it doesn't exist"
        )
      )
    end

    it_behaves_like 'logs the failure' do
      let(:failed_project) { unauthorized_project }
      let(:failure_message) { "You don't have permission to enable this agent or flow, or it doesn't exist" }
    end
  end

  context 'when a consumer is already configured for the projects' do
    before do
      described_class.new(current_user:, item:, projects:).execute
    end

    it 'counts the already configured projects as successes', :aggregate_failures do
      expect { execute }.not_to change { Ai::Catalog::ItemConsumer.count }

      expect(execute).to be_success
      expect(execute.payload[:successful_count]).to eq(2)
      expect(execute.payload[:failures]).to be_empty
    end
  end

  context 'when the create service raises an exception' do
    let(:projects) { Project.id_in([project_1.id]) }

    before do
      allow(::Ai::Catalog::ItemConsumers::CreateService).to receive(:new).and_raise(StandardError, 'unexpected error')
    end

    it 'catches the exception and adds it to failures', :aggregate_failures do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        an_instance_of(StandardError),
        project_id: project_1.id,
        item_id: item.id
      )

      expect(execute).to be_success
      expect(execute.payload[:successful_count]).to eq(0)
      expect(execute.payload[:failures]).to contain_exactly(
        a_hash_including(
          project_id: project_1.id,
          error_message: 'Something went wrong on our end whilst processing this project'
        )
      )
    end

    it_behaves_like 'logs the failure' do
      let(:failed_project) { project_1 }
      let(:failure_message) { 'Something went wrong on our end whilst processing this project' }
    end
  end
end
