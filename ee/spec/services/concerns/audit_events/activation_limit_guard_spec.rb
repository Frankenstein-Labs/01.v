# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::ActivationLimitGuard, feature_category: :audit_events do
  let(:test_class) do
    Class.new do
      include AuditEvents::ActivationLimitGuard

      def self.name
        'TestDestination'
      end
    end
  end

  let(:test_instance) { test_class.new }
  let(:destination) { instance_double(AuditEvents::Group::ExternalStreamingDestination) }
  let(:destination_class) { class_double(AuditEvents::Group::ExternalStreamingDestination) }
  let(:limits) { instance_double(PlanLimits) }
  let(:scope_relation) { instance_double(Group) }
  let(:active_scope) { instance_double(ActiveRecord::Relation) }
  let(:plan) { instance_double(Plan) }

  before do
    allow(destination).to receive(:class).and_return(destination_class)
  end

  describe '#validate_activation_limit' do
    subject(:validate_activation_limit) { test_instance.send(:validate_activation_limit, destination, active_value) }

    context 'when active_value is not true' do
      let(:active_value) { false }

      it { is_expected.to be_nil }
    end

    context 'when active_value is nil' do
      let(:active_value) { nil }

      it { is_expected.to be_nil }
    end

    context 'when destination is already active' do
      let(:active_value) { true }

      before do
        allow(destination).to receive(:active?).and_return(true)
      end

      it { is_expected.to be_nil }
    end

    context 'when destination class does not respond to limit_relation' do
      let(:active_value) { true }

      before do
        allow(destination).to receive(:active?).and_return(false)
        allow(destination_class).to receive(:respond_to?).with(:limit_relation).and_return(false)
      end

      it { is_expected.to be_nil }
    end

    context 'when destination class responds to limit_relation' do
      let(:active_value) { true }
      let(:limit_name) { :audit_event_streaming_destinations }
      let(:limit_value) { 5 }

      before do
        allow(destination).to receive(:active?).and_return(false)
        allow(destination_class).to receive_messages(
          respond_to?: true,
          limit_name: limit_name
        )
        allow(limits).to receive(:public_send).with(limit_name).and_return(limit_value)
      end

      context 'with global scope' do
        before do
          allow(destination_class).to receive_messages(
            limit_scope: Limitable::GLOBAL_SCOPE,
            active: active_scope
          )
          allow(active_scope).to receive(:count).and_return(current_active_count)
          allow(Plan).to receive(:default).and_return(plan)
          allow(plan).to receive(:actual_limits).and_return(limits)
        end

        context 'when current active count is below limit' do
          let(:current_active_count) { 3 }

          it { is_expected.to be_nil }
        end

        context 'when current active count equals limit' do
          let(:current_active_count) { 5 }

          it 'returns error hash' do
            expect(validate_activation_limit).to eq({
              error: "Cannot activate: Maximum number of audit event streaming destinations (5) exceeded"
            })
          end
        end

        context 'when current active count exceeds limit' do
          let(:current_active_count) { 6 }

          it 'returns error hash' do
            expect(validate_activation_limit).to eq({
              error: "Cannot activate: Maximum number of audit event streaming destinations (5) exceeded"
            })
          end
        end

        context 'when limit_value is nil' do
          let(:limit_value) { nil }
          let(:current_active_count) { 10 }

          it { is_expected.to be_nil }
        end
      end

      context 'with scoped relation' do
        let(:scope_name) { :group }
        let(:scoped_active_scope) { instance_double(ActiveRecord::Relation) }

        before do
          allow(destination_class).to receive_messages(
            limit_scope: scope_name,
            active_for_scope: scoped_active_scope
          )
          allow(destination).to receive(:public_send).with(scope_name).and_return(scope_relation)
          allow(scoped_active_scope).to receive(:count).and_return(current_active_count)
          allow(scope_relation).to receive(:actual_limits).and_return(limits)
        end

        context 'when current active count is below limit' do
          let(:current_active_count) { 3 }

          it { is_expected.to be_nil }
        end

        context 'when current active count equals limit' do
          let(:current_active_count) { 5 }

          it 'returns error hash' do
            expect(validate_activation_limit).to eq({
              error: "Cannot activate: Maximum number of audit event streaming destinations (5) exceeded"
            })
          end
        end

        context 'when scope_relation is nil' do
          let(:current_active_count) { 3 }

          before do
            allow(destination).to receive(:public_send).with(scope_name).and_return(nil)
          end

          it { is_expected.to be_nil }
        end
      end
    end
  end

  describe '#validate_activation_limit_for_update' do
    subject(:validate_activation_limit_for_update) do
      test_instance.send(:validate_activation_limit_for_update, destination, active_value)
    end

    context 'when active_value is not present' do
      let(:active_value) { nil }

      it { is_expected.to be_nil }
    end

    context 'when active_value is false' do
      let(:active_value) { false }

      it { is_expected.to be_nil }
    end

    context 'when active_value is present' do
      let(:active_value) { true }

      context 'when validation passes' do
        before do
          allow(test_instance).to receive(:validate_activation_limit).with(destination, active_value).and_return(nil)
        end

        it { is_expected.to be_nil }
      end

      context 'when validation fails' do
        let(:error_message) { "Cannot activate: Maximum number of audit event streaming destinations (5) exceeded" }

        before do
          allow(test_instance).to receive(:validate_activation_limit).with(destination,
            active_value).and_return({ error: error_message })
        end

        it { is_expected.to eq(error_message) }
      end
    end
  end
end
