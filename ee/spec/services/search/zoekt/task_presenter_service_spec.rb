# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::TaskPresenterService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node) }
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:task) { create(:zoekt_task, node: node, project: project) }
  let_it_be(:delete_task) { create(:zoekt_task, node: node, task_type: :delete_repo) }

  let(:service) { described_class.new(node) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(node).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(node)
    end
  end

  describe '#execute' do
    context 'when application setting zoekt_indexing_paused is true' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: true)
      end

      it 'excludes zoekt tasks' do
        expect(execute_task).to eq([])
      end
    end

    context 'when application setting zoekt_indexing_paused is false' do
      before do
        stub_ee_application_setting(zoekt_indexing_paused: false)
      end

      it 'returns serialized tasks' do
        expect(execute_task).to eq([
          ::Search::Zoekt::TaskSerializerService.execute(task, node),
          ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
        ])
      end

      context "when concurrency limit is lower than all tasks" do
        before do
          allow(node).to receive(:concurrency_limit).and_return(2)
        end

        it "returns a subset of zoekt" do
          expect(execute_task).to eq([
            ::Search::Zoekt::TaskSerializerService.execute(task, node),
            ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
          ])
        end
      end
    end

    context 'when critical storage watermark is exceeded' do
      it 'only presents delete repo tasks' do
        expect(node).to receive(:watermark_exceeded_critical?).and_return(true)
        expect(execute_task).to eq([
          ::Search::Zoekt::TaskSerializerService.execute(delete_task, node)
        ])
      end
    end
  end
end
