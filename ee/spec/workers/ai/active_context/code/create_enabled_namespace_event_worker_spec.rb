# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::CreateEnabledNamespaceEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::CreateEnabledNamespaceEvent.new(data: {}) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, :elasticsearch)
  end

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  before do
    allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
  end

  describe '#handle_event' do
    context 'when on saas', :saas do
      let_it_be(:namespace_with_ultimate_subscription) do
        create(:group_with_plan, plan: :ultimate_plan).tap do |group|
          group.namespace_settings.update!(duo_features_enabled: true)
        end
      end

      let_it_be(:namespace_with_premium_subscription) do
        create(:group_with_plan, plan: :premium_plan).tap do |group|
          group.namespace_settings.update!(duo_features_enabled: true)
        end
      end

      let_it_be(:namespace_without_subscription) { create(:group) }
      let_it_be(:expired_subscription_namespace) do
        create(:group).tap do |group|
          create(:gitlab_subscription, :expired, namespace: group)
        end
      end

      before do
        stub_saas_features(duo_chat_on_saas: true)
      end

      it 'processes namespaces with valid subscriptions and AI enabled' do
        expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(2)

        enabled_namespaces = Ai::ActiveContext::Code::EnabledNamespace.all
        expect(enabled_namespaces.pluck(:namespace_id)).to contain_exactly(
          namespace_with_ultimate_subscription.id,
          namespace_with_premium_subscription.id
        )
        expect(enabled_namespaces.pluck(:connection_id).uniq).to eq([connection.id])
        expect(enabled_namespaces.pluck(:state).uniq).to eq(['ready'])
      end

      it 'does not process namespaces without valid subscriptions' do
        execute

        expect(Ai::ActiveContext::Code::EnabledNamespace.pluck(:namespace_id))
          .not_to include(namespace_without_subscription.id, expired_subscription_namespace.id)
      end

      context 'when processing multiple batches' do
        let_it_be(:namespace_with_silver_subscription) do
          create(:group_with_plan, plan: :silver_plan).tap do |group|
            group.namespace_settings.update!(duo_features_enabled: true)
          end
        end

        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
          stub_const("#{described_class}::LIMIT", 2)
        end

        it 'stops processing after reaching LIMIT and reemits the event with last_processed_id' do
          subscriptions = GitlabSubscription.with_active_paid_or_trial_hosted_plan.order(:id).limit(2)
          expected_last_id = subscriptions.last.id

          expect(Gitlab::EventStore).to receive(:publish).with(
            an_instance_of(Ai::ActiveContext::Code::CreateEnabledNamespaceEvent)
          ).and_wrap_original do |method, event|
            expect(event.data[:last_processed_id]).to eq(expected_last_id)
            method.call(event)
          end

          execute

          expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(2)
        end

        context 'when resuming from last_processed_id' do
          it 'continues processing from the last processed ID without re-processing previous records' do
            first_event = Ai::ActiveContext::Code::CreateEnabledNamespaceEvent.new(data: {})

            last_processed_id = nil
            allow(Gitlab::EventStore).to receive(:publish).and_wrap_original do |method, event|
              last_processed_id = event.data[:last_processed_id]
              method.call(event)
            end

            consume_event(subscriber: described_class, event: first_event)
            expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(2)

            second_event = Ai::ActiveContext::Code::CreateEnabledNamespaceEvent.new(
              data: { last_processed_id: last_processed_id }
            )

            consume_event(subscriber: described_class, event: second_event)

            expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(3)
          end
        end
      end

      context 'when namespace already has enabled namespace record' do
        before do
          create(:ai_active_context_code_enabled_namespace,
            namespace: namespace_with_ultimate_subscription,
            active_context_connection: connection)
          create(:ai_active_context_code_enabled_namespace,
            namespace: namespace_with_premium_subscription,
            active_context_connection: connection)
        end

        it 'does not create duplicate records' do
          expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }
        end
      end
    end

    context 'when not on saas' do
      let_it_be(:namespace1) { create(:group) }
      let_it_be(:namespace2) { create(:group) }
      let_it_be(:namespace3) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: namespace1) }

      context 'when instance is not eligible' do
        context 'when AI features are not available' do
          before do
            allow(::License).to receive(:ai_features_available?).and_return(false)
          end

          it 'returns false and does not process namespaces' do
            expect(Ai::ActiveContext::Code::EnabledNamespace).not_to receive(:insert_all)
            expect(execute).to eq([{}])
          end
        end

        context 'when instance level AI beta features are disabled' do
          before do
            allow(::License).to receive(:ai_features_available?).and_return(true)
            allow(::Gitlab::CurrentSettings).to receive(:instance_level_ai_beta_features_enabled?).and_return(false)
          end

          it 'returns false and does not process namespaces' do
            expect(Ai::ActiveContext::Code::EnabledNamespace).not_to receive(:insert_all)
            expect(execute).to eq([{}])
          end
        end
      end

      context 'when all conditions are met' do
        before do
          allow(::License).to receive(:ai_features_available?).and_return(true)
          allow(::Gitlab::CurrentSettings).to receive(:instance_level_ai_beta_features_enabled?).and_return(true)
        end

        it 'processes namespaces in batches and creates enabled namespace records' do
          expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(3)

          enabled_namespaces = Ai::ActiveContext::Code::EnabledNamespace.all
          expect(enabled_namespaces.pluck(:namespace_id)).to contain_exactly(namespace1.id, namespace2.id,
            namespace3.id)
          expect(enabled_namespaces.pluck(:connection_id).uniq).to eq([connection.id])
          expect(enabled_namespaces.pluck(:state).uniq).to eq(['ready'])
        end

        it 'only processes top-level group namespaces' do
          execute

          expect(Ai::ActiveContext::Code::EnabledNamespace.pluck(:namespace_id)).not_to include(subgroup.id)
        end

        context 'when some namespaces already have enabled namespace records' do
          before do
            create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
              active_context_connection: connection)
          end

          it 'only creates records for namespaces that do not have them' do
            expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(2)
          end
        end

        context 'when processing multiple batches' do
          before do
            stub_const("#{described_class}::BATCH_SIZE", 2)
            stub_const("#{described_class}::LIMIT", 2)
          end

          it 'stops after processing LIMIT records' do
            expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(2)
          end

          it 'reemits the event with last_processed_id when reaching LIMIT' do
            expected_last_id = Namespace.group_namespaces.top_level.order(:id).second.id

            expect(Gitlab::EventStore).to receive(:publish).with(
              an_instance_of(Ai::ActiveContext::Code::CreateEnabledNamespaceEvent)
            ).and_wrap_original do |method, event|
              expect(event.data[:last_processed_id]).to eq(expected_last_id)
              method.call(event)
            end

            execute
          end

          context 'when resuming from last_processed_id' do
            it 'continues processing from the last processed ID without re-processing previous records' do
              first_event = Ai::ActiveContext::Code::CreateEnabledNamespaceEvent.new(data: {})

              last_processed_id = nil
              allow(Gitlab::EventStore).to receive(:publish).and_wrap_original do |method, event|
                last_processed_id = event.data[:last_processed_id]
                method.call(event)
              end

              consume_event(subscriber: described_class, event: first_event)
              expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(2)

              second_event = Ai::ActiveContext::Code::CreateEnabledNamespaceEvent.new(
                data: { last_processed_id: last_processed_id }
              )

              consume_event(subscriber: described_class, event: second_event)

              expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(3)
            end
          end
        end

        context 'when there are no eligible namespaces' do
          before do
            Ai::ActiveContext::Code::EnabledNamespace
              .where(namespace_id: [namespace1.id, namespace2.id, namespace3.id]).delete_all
            create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
              active_context_connection: connection)
            create(:ai_active_context_code_enabled_namespace, namespace: namespace2,
              active_context_connection: connection)
            create(:ai_active_context_code_enabled_namespace, namespace: namespace3,
              active_context_connection: connection)
          end

          it 'does not create any records' do
            expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }
          end
        end

        context 'when there are no top-level group namespaces' do
          before do
            Namespace.delete_all
          end

          it 'does not create any records' do
            expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }
          end
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'returns false and does not process namespaces' do
        expect(Ai::ActiveContext::Code::EnabledNamespace).not_to receive(:insert_all)
        expect(execute).to eq([{}])
      end
    end
  end
end
