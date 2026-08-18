# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(data: {}) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, adapter_class: ActiveContext::Databases::Elasticsearch::Adapter, active: true)
  end

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  before do
    allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
  end

  describe '#handle_event' do
    let(:worker) { described_class.new }

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'returns false without processing' do
        result = worker.handle_event(event)
        expect(result).to be false
      end
    end

    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'when not on saas and instance is invalid' do
        before do
          allow(worker).to receive_messages(gitlab_com: false, instance_valid?: false)
        end

        it 'calls process_in_batches! with last_processed_id from event data' do
          event_with_id = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(
            data: { last_processed_id: 99 }
          )

          expect(worker).to receive(:process_in_batches!).with(99)
          worker.handle_event(event_with_id)
        end
      end

      context 'when on saas' do
        before do
          allow(worker).to receive(:gitlab_com).and_return(true)
        end

        it 'calls process_in_batches! with last_processed_id from event data' do
          event_with_id = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(
            data: { last_processed_id: 42 }
          )

          expect(worker).to receive(:process_in_batches!).with(42)
          worker.handle_event(event_with_id)
        end

        it 'calls process_in_batches! with nil when event data is empty' do
          expect(worker).to receive(:process_in_batches!).with(nil)
          worker.handle_event(event)
        end
      end

      context 'when not on saas and instance is valid' do
        before do
          allow(worker).to receive_messages(gitlab_com: false, instance_valid?: true)
        end

        it 'returns false without processing' do
          result = worker.handle_event(event)
          expect(result).to be false
        end
      end
    end

    context 'when on saas', :saas do
      let_it_be(:namespace_with_subscription) do
        create(:group_with_plan, plan: :ultimate_plan)
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

      it 'deletes enabled namespace records for namespaces without valid subscriptions' do
        create(:ai_active_context_code_enabled_namespace,
          namespace: namespace_without_subscription,
          active_context_connection: connection)
        create(:ai_active_context_code_enabled_namespace,
          namespace: expired_subscription_namespace,
          active_context_connection: connection)

        expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(-2)

        expect(Ai::ActiveContext::Code::EnabledNamespace.pluck(:namespace_id))
          .not_to include(namespace_without_subscription.id, expired_subscription_namespace.id)
      end

      it 'does not delete enabled namespace records for namespaces with valid subscriptions' do
        create(:ai_active_context_code_enabled_namespace,
          namespace: namespace_with_subscription,
          active_context_connection: connection)

        expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }

        expect(Ai::ActiveContext::Code::EnabledNamespace.pluck(:namespace_id))
          .to include(namespace_with_subscription.id)
      end

      context 'when processing multiple batches' do
        let_it_be(:invalid_namespaces) { create_list(:group, 7) }

        before do
          invalid_namespaces.each do |namespace|
            create(:ai_active_context_code_enabled_namespace,
              namespace: namespace,
              active_context_connection: connection)
          end

          stub_const("#{described_class}::LIMIT", 6)
          stub_const("#{described_class}::BATCH_SIZE", 3)
        end

        it 'stops processing after reaching LIMIT and reemits the event with last_processed_id' do
          enabled_namespaces = Ai::ActiveContext::Code::EnabledNamespace.order(:id).limit(6)
          expected_last_id = enabled_namespaces.last.id

          expect(Gitlab::EventStore).to receive(:publish).with(
            an_instance_of(Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent)
          ).and_wrap_original do |method, event|
            expect(event.data[:last_processed_id]).to eq(expected_last_id)
            method.call(event)
          end

          execute

          expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(1)
        end

        context 'when resuming from last_processed_id' do
          it 'continues processing from the last processed ID' do
            first_event = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(data: {})

            last_processed_id = nil
            allow(Gitlab::EventStore).to receive(:publish).and_wrap_original do |method, event|
              last_processed_id = event.data[:last_processed_id]
              method.call(event)
            end

            consume_event(subscriber: described_class, event: first_event)
            expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(1)

            second_event = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(
              data: { last_processed_id: last_processed_id }
            )

            consume_event(subscriber: described_class, event: second_event)

            expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(0)
          end
        end
      end
    end

    context 'when not on saas' do
      let_it_be(:namespace1) { create(:group) }
      let_it_be(:namespace2) { create(:group) }
      let_it_be(:namespace3) { create(:group) }

      context 'when instance is valid' do
        before do
          allow(::License).to receive(:ai_features_available?).and_return(true)
          allow(::Gitlab::CurrentSettings).to receive(:instance_level_ai_beta_features_enabled?).and_return(true)
        end

        it 'does not delete any enabled namespace records' do
          create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
            active_context_connection: connection)
          create(:ai_active_context_code_enabled_namespace, namespace: namespace2,
            active_context_connection: connection)

          expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }
        end
      end

      context 'when instance is invalid' do
        context 'when AI features are not available' do
          before do
            allow(::License).to receive(:ai_features_available?).and_return(false)
            allow(::Gitlab::CurrentSettings).to receive(:instance_level_ai_beta_features_enabled?).and_return(true)
          end

          it 'deletes all enabled namespace records' do
            create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
              active_context_connection: connection)
            create(:ai_active_context_code_enabled_namespace, namespace: namespace2,
              active_context_connection: connection)
            create(:ai_active_context_code_enabled_namespace, namespace: namespace3,
              active_context_connection: connection)

            expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(-3)
          end
        end

        context 'when instance level AI beta features are disabled' do
          before do
            allow(::License).to receive(:ai_features_available?).and_return(true)
            allow(::Gitlab::CurrentSettings).to receive(:instance_level_ai_beta_features_enabled?).and_return(false)
          end

          it 'deletes all enabled namespace records' do
            create(:ai_active_context_code_enabled_namespace, namespace: namespace1,
              active_context_connection: connection)
            create(:ai_active_context_code_enabled_namespace, namespace: namespace2,
              active_context_connection: connection)

            expect { execute }.to change { Ai::ActiveContext::Code::EnabledNamespace.count }.by(-2)
          end
        end

        context 'when processing multiple batches' do
          let_it_be(:namespaces) { create_list(:group, 7) }

          before do
            allow(::License).to receive(:ai_features_available?).and_return(false)

            namespaces.each do |namespace|
              create(:ai_active_context_code_enabled_namespace,
                namespace: namespace,
                active_context_connection: connection)
            end

            stub_const("#{described_class}::LIMIT", 6)
            stub_const("#{described_class}::BATCH_SIZE", 3)
          end

          it 'stops processing after reaching LIMIT and reemits the event with last_processed_id' do
            enabled_namespaces = Ai::ActiveContext::Code::EnabledNamespace.order(:id).limit(6)
            expected_last_id = enabled_namespaces.last.id

            expect(Gitlab::EventStore).to receive(:publish).with(
              an_instance_of(Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent)
            ).and_wrap_original do |method, event|
              expect(event.data[:last_processed_id]).to eq(expected_last_id)
              method.call(event)
            end

            execute

            expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(1)
          end

          context 'when resuming from last_processed_id' do
            it 'continues processing from the last processed ID' do
              first_event = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(data: {})

              last_processed_id = nil
              allow(Gitlab::EventStore).to receive(:publish).and_wrap_original do |method, event|
                last_processed_id = event.data[:last_processed_id]
                method.call(event)
              end

              consume_event(subscriber: described_class, event: first_event)
              expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(1)

              second_event = Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent.new(
                data: { last_processed_id: last_processed_id }
              )

              consume_event(subscriber: described_class, event: second_event)

              expect(Ai::ActiveContext::Code::EnabledNamespace.count).to eq(0)
            end
          end
        end
      end

      context 'when there are no enabled namespace records' do
        before do
          allow(::License).to receive(:ai_features_available?).and_return(false)
        end

        it 'does not delete any records' do
          expect { execute }.not_to change { Ai::ActiveContext::Code::EnabledNamespace.count }
        end
      end
    end
  end
end
