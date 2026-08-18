# frozen_string_literal: true

RSpec.shared_examples 'activation limit guard for audit event streaming destinations' do |destination_type|
  let(:destination_class) do
    if destination_type == :group
      AuditEvents::Group::ExternalStreamingDestination
    else
      AuditEvents::Instance::ExternalStreamingDestination
    end
  end

  let(:factory_name) do
    if destination_type == :group
      :audit_events_group_external_streaming_destination
    else
      :audit_events_instance_external_streaming_destination
    end
  end

  let(:limit_name) { :external_audit_event_destinations }
  let(:limit_value) { 3 }
  let(:error_message) do
    "Cannot activate: Maximum number of audit event streaming destinations (#{limit_value}) exceeded"
  end

  describe 'activation limit validation' do
    context 'when activating a destination' do
      let(:active) { true }

      context 'when destination is already active' do
        let(:destination) { create(factory_name, active: true) }

        it 'does not validate limits and updates successfully' do
          expect { subject }.not_to raise_error
          expect(subject[:errors]).to be_empty
          expect(subject[:external_audit_event_destination]).to be_present
        end
      end

      context 'when destination is inactive' do
        let(:destination) { create(factory_name, active: false) }

        before do
          allow(destination_class).to receive_messages(
            limit_name: limit_name,
            respond_to?: true
          )
          allow(destination_class).to receive(:respond_to?).with(:limit_relation).and_return(true)
        end

        context 'when limit is not exceeded' do
          before do
            active_scope = instance_double(ActiveRecord::Relation)
            limits = instance_double(PlanLimits)

            allow(active_scope).to receive(:count).and_return(limit_value - 1)
            allow(limits).to receive(:public_send).with(limit_name).and_return(limit_value)

            if destination_type == :group
              allow(destination_class).to receive_messages(
                limit_scope: :group,
                active_for_scope: active_scope
              )
              allow(destination_class).to receive(:active_for_scope).with(destination.group).and_return(active_scope)
              allow(destination.group).to receive(:actual_limits).and_return(limits)
            else
              plan = instance_double(Plan)

              allow(destination_class).to receive_messages(
                limit_scope: Limitable::GLOBAL_SCOPE,
                active: active_scope
              )
              allow(Plan).to receive(:default).and_return(plan)
              allow(plan).to receive(:actual_limits).and_return(limits)
            end
          end

          it 'validates limits and updates successfully' do
            expect { subject }.not_to raise_error
            expect(subject[:errors]).to be_empty
            expect(subject[:external_audit_event_destination]).to be_present
            expect(subject[:external_audit_event_destination]['active']).to be true
          end
        end

        context 'when limit is exceeded' do
          before do
            active_scope = instance_double(ActiveRecord::Relation)
            limits = instance_double(PlanLimits)

            allow(active_scope).to receive(:count).and_return(limit_value)
            allow(limits).to receive(:public_send).with(limit_name).and_return(limit_value)

            if destination_type == :group
              allow(destination_class).to receive_messages(
                limit_scope: :group,
                active_for_scope: active_scope
              )
              allow(destination_class).to receive(:active_for_scope).with(destination.group).and_return(active_scope)
              allow(destination.group).to receive(:actual_limits).and_return(limits)
            else
              plan = instance_double(Plan)

              allow(destination_class).to receive_messages(
                limit_scope: Limitable::GLOBAL_SCOPE,
                active: active_scope
              )
              allow(Plan).to receive(:default).and_return(plan)
              allow(plan).to receive(:actual_limits).and_return(limits)
            end
          end

          it 'returns validation error and does not update' do
            expect(subject[:external_audit_event_destination]).to be_nil
            expect(subject[:errors]).to contain_exactly(error_message)
            expect(destination.reload.active).to be false
          end
        end

        context 'when limit is nil' do
          before do
            active_scope = instance_double(ActiveRecord::Relation)
            limits = instance_double(PlanLimits)

            allow(active_scope).to receive(:count).and_return(100)
            allow(limits).to receive(:public_send).with(limit_name).and_return(nil)

            if destination_type == :group
              allow(destination_class).to receive_messages(
                limit_scope: :group,
                active_for_scope: active_scope
              )
              allow(destination_class).to receive(:active_for_scope).with(destination.group).and_return(active_scope)
              allow(destination.group).to receive(:actual_limits).and_return(limits)
            else
              plan = instance_double(Plan)

              allow(destination_class).to receive_messages(
                limit_scope: Limitable::GLOBAL_SCOPE,
                active: active_scope
              )
              allow(Plan).to receive(:default).and_return(plan)
              allow(plan).to receive(:actual_limits).and_return(limits)
            end
          end

          it 'does not validate limits and updates successfully' do
            expect { subject }.not_to raise_error
            expect(subject[:errors]).to be_empty
            expect(subject[:external_audit_event_destination]).to be_present
            expect(subject[:external_audit_event_destination]['active']).to be true
          end
        end
      end
    end

    context 'when deactivating a destination' do
      let(:active) { false }
      let(:destination) { create(factory_name, active: true) }

      it 'does not validate limits and updates successfully' do
        expect { subject }.not_to raise_error
        expect(subject[:errors]).to be_empty
        expect(subject[:external_audit_event_destination]).to be_present
        expect(subject[:external_audit_event_destination]['active']).to be false
      end
    end

    context 'when active parameter is nil' do
      let(:active) { nil }
      let(:destination) { create(factory_name, active: false) }

      it 'does not validate limits and updates successfully' do
        expect { subject }.not_to raise_error
        expect(subject[:errors]).to be_empty
        expect(subject[:external_audit_event_destination]).to be_present
      end
    end

    context 'when destination class does not respond to limit_relation' do
      let(:active) { true }
      let(:destination) { create(factory_name, active: false) }

      before do
        # Add stub defaults to prevent mock expectation errors
        allow(destination_class).to receive(:respond_to?).and_return(false)
        allow(destination_class).to receive(:respond_to?).with(:limit_relation).and_return(false)
      end

      it 'does not validate limits and updates successfully' do
        expect { subject }.not_to raise_error
        expect(subject[:errors]).to be_empty
        expect(subject[:external_audit_event_destination]).to be_present
        expect(subject[:external_audit_event_destination]['active']).to be true
      end
    end
  end
end

RSpec.shared_examples 'activation limit guard for group audit event streaming destinations' do
  include_examples 'activation limit guard for audit event streaming destinations', :group
end

RSpec.shared_examples 'activation limit guard for instance audit event streaming destinations' do
  include_examples 'activation limit guard for audit event streaming destinations', :instance
end
