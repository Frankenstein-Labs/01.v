# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::UpdateInstanceVariablesService, feature_category: :pipeline_composition do
  let_it_be(:current_user) { create :user }
  let(:params) { { variables_attributes: variables_attributes } }

  subject(:service) { described_class.new(params, current_user) }

  before do
    stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
  end

  def expect_to_stream(event_name:)
    expect_any_instance_of(AuditEvents::InstanceAuditEvent) do |event|
      expect(event).to receive(:stream_to_external_destinations).with(use_json: anything, event_name: event_name)
    end
  end

  context 'with insert only variables' do
    let(:variables_attributes) do
      [
        { key: 'var_a', value: 'dummy_value_for_a', protected: true },
        { key: 'var_b', value: 'dummy_value_for_b', protected: false }
      ]
    end

    it 'persists attributes' do
      expect { service.execute }.to change { Ci::InstanceVariable.count }.by(2)
    end
  end

  context 'with update only variables' do
    let!(:var_a) { create(:ci_instance_variable) }
    let!(:var_b) { create(:ci_instance_variable, protected: false) }

    let(:variables_attributes) do
      [
        {
          id: var_a.id,
          key: var_a.key,
          value: 'new_dummy_value_for_a',
          protected: var_a.protected?.to_s
        },
        {
          id: var_b.id,
          key: 'var_b_key',
          value: 'new_dummy_value_for_b',
          protected: 'true'
        }
      ]
    end

    it 'does not change the count' do
      expect { service.execute }
        .to not_change { Ci::InstanceVariable.count }
    end
  end

  describe 'auditing' do
    context 'with update only variables' do
      let!(:var_a) { create(:ci_instance_variable) }
      let!(:var_b) { create(:ci_instance_variable, protected: false) }

      let(:variables_attributes) do
        [
          {
            id: var_a.id,
            key: var_a.key,
            value: 'new_dummy_value_for_a',
            protected: var_a.protected?.to_s
          },
          {
            id: var_b.id,
            key: 'var_b_key',
            value: 'new_dummy_value_for_b',
            protected: 'true'
          }
        ]
      end

      it 'does not change the count' do
        expect { service.execute }
          .to not_change { Ci::InstanceVariable.count }
      end
    end

    context 'with insert and update variables' do
      let!(:var_a) { create(:ci_instance_variable) }

      let(:variables_attributes) do
        [
          {
            id: var_a.id,
            key: var_a.key,
            value: 'new_dummy_value_for_a',
            protected: var_a.protected?.to_s
          },
          {
            key: 'var_b',
            value: 'dummy_value_for_b',
            protected: 'true'
          }
        ]
      end

      it 'audits changes' do
        expect_to_stream event_name: :ci_instance_variable_updated
        expect_to_stream event_name: :ci_instance_variable_created

        expect { service.execute }.to change { AuditEventReader.count }.by(2)
      end
    end

    context 'with insert, update, and destroy variables' do
      let!(:var_a) { create(:ci_instance_variable) }
      let!(:var_b) { create(:ci_instance_variable) }

      let(:variables_attributes) do
        [
          {
            id: var_a.id,
            key: var_a.key,
            value: 'new_dummy_value_for_a',
            protected: var_a.protected?.to_s
          },
          {
            id: var_b.id,
            key: var_b.key,
            value: 'dummy_value_for_b',
            protected: var_b.protected?.to_s,
            '_destroy' => 'true'
          },
          {
            key: 'var_c',
            value: 'dummy_value_for_c',
            protected: true
          }
        ]
      end

      it 'audits changes' do
        expect_to_stream event_name: :ci_instance_variable_updated
        expect_to_stream event_name: :ci_instance_variable_created
        expect_to_stream event_name: :ci_instance_variable_destroyed

        expect { service.execute }.to change { AuditEventReader.count }.by(3)
      end
    end

    context 'with invalid variables' do
      let_it_be(:var_a) { create(:ci_instance_variable, value: 'dummy_value_for_a') }

      let(:variables_attributes) do
        [
          {
            key: '...?',
            value: 'nice_value'
          },
          {
            id: var_a.id,
            key: var_a.key,
            value: 'new_dummy_value_for_a',
            protected: var_a.protected?.to_s
          },
          {
            key: var_a.key,
            value: 'other_value'
          }
        ]
      end

      it { expect(service.execute).to be_falsey }

      it 'does not insert any records' do
        expect { service.execute }
          .not_to change { Ci::InstanceVariable.count }
      end

      it 'does not audit' do
        expect { service.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when deleting non existing variables' do
      let(:variables_attributes) do
        [
          {
            id: 'some-id',
            key: 'some_key',
            value: 'other_value',
            '_destroy' => 'true'
          }
        ]
      end

      it 'does not audit' do
        expect { service.execute }.to raise_error ActiveRecord::RecordNotFound
        expect(AuditEventReader.count).to eq(0)
      end
    end

    context 'when updating non existing variables' do
      let(:variables_attributes) do
        [
          {
            id: 'some-id',
            key: 'some_key',
            value: 'other_value'
          }
        ]
      end

      it 'does not audit' do
        expect { service.execute }.to raise_error ActiveRecord::RecordNotFound
        expect(AuditEventReader.count).to eq(0)
      end
    end
  end
end
