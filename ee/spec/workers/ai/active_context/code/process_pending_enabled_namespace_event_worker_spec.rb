# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::ProcessPendingEnabledNamespaceEventWorker, feature_category: :global_search do
  let(:event_class) { Ai::ActiveContext::Code::ProcessPendingEnabledNamespaceEvent }
  let(:event) { event_class.new(data: {}) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, :elasticsearch)
  end

  let_it_be(:namespace) { create(:group) }
  let_it_be(:project_1) { create(:project, group: namespace) }
  let_it_be(:project_2) { create(:project, group: namespace) }
  let_it_be(:project_3) { create(:project) }

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  before do
    allow(Gitlab::EventStore).to receive(:publish).and_return(true)
  end

  context 'when indexing is enabled' do
    before do
      allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
    end

    context 'when there are enabled namespaces to process' do
      let!(:enabled_namespace) do
        create(:ai_active_context_code_enabled_namespace, namespace: namespace, connection_id: connection.id,
          state: :pending)
      end

      context 'when some projects have duo_features_enabled' do
        before do
          [project_1, project_2, project_3].each do |project|
            project.project_setting.update!(duo_features_enabled: true)
          end
        end

        it 'creates repository records for the namespace projects and sets enabled_namespace to ready' do
          expect(enabled_namespace.state).to eq('pending')

          expect { execute }.to change { Ai::ActiveContext::Code::Repository.count }.by(2)

          expect(enabled_namespace.reload.state).to eq('ready')

          klass = Ai::ActiveContext::Code::Repository
          expect(klass.pluck(:project_id)).to contain_exactly(project_1.id, project_2.id)
          expect(klass.pluck(:enabled_namespace_id).uniq).to contain_exactly(enabled_namespace.id)
          expect(klass.pluck(:connection_id).uniq).to contain_exactly(connection.id)
        end

        context 'when some repositories already exist' do
          before do
            create(:ai_active_context_code_repository, project: project_1, enabled_namespace: enabled_namespace,
              connection_id: connection.id)
          end

          it 'creates repository records for records that do not exist only' do
            expect(enabled_namespace.state).to eq('pending')

            expect { execute }.to change { Ai::ActiveContext::Code::Repository.count }.by(1)

            expect(enabled_namespace.reload.state).to eq('ready')

            klass = Ai::ActiveContext::Code::Repository
            expect(klass.pluck(:project_id)).to contain_exactly(project_1.id, project_2.id)
            expect(klass.distinct.pluck(:enabled_namespace_id)).to contain_exactly(enabled_namespace.id)
            expect(klass.distinct.pluck(:connection_id)).to contain_exactly(connection.id)
          end
        end

        context 'when a failure occurs' do
          before do
            allow_next_instance_of(Ai::ActiveContext::Code::Repository) do |repository|
              allow(repository).to receive(:persisted?).and_return(false)
            end
          end

          it 'does not change the enabled_namespace state' do
            expect { execute }.not_to change { enabled_namespace.reload.state }.from('pending')
          end
        end
      end

      context 'when no projects have duo_features_enabled' do
        before do
          [project_1, project_2, project_3].each do |project|
            project.reload.project_setting.update!(duo_features_enabled: false)
          end
        end

        it 'does not create repositories but marks enabled namespace as ready' do
          expect(enabled_namespace.state).to eq('pending')

          expect { execute }.not_to change { Ai::ActiveContext::Code::Repository.count }

          expect(enabled_namespace.reload.state).to eq('ready')
        end
      end

      context 'when there are more enabled namespaces to process' do
        before do
          create(:ai_active_context_code_enabled_namespace, connection_id: connection.id, state: :pending)
        end

        it 'emits another event' do
          expect(Gitlab::EventStore).to receive(:publish).with(
            an_object_having_attributes(class: event_class, data: {})
          )

          execute
        end
      end
    end

    context 'when there are no enabled namespaces to process' do
      it 'does not change the enabled_namespace state' do
        expect(Ai::ActiveContext::Code::Repository).not_to receive(:create)

        execute
      end
    end
  end
end
