# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Event, feature_category: :duo_agent_platform do
  let(:workflow) { create(:duo_workflows_workflow) }
  let_it_be(:project) { create(:project) }

  it { is_expected.to validate_presence_of(:event_type) }
  it { is_expected.to validate_presence_of(:event_status) }

  it_behaves_like 'sync workflow attributes' do
    subject { build(:duo_workflows_event) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'correlation_id_value validation' do
    let(:valid_uuid) { '123e4567-e89b-12d3-a456-426614174000' }

    subject(:event) do
      build(:duo_workflows_event,
        workflow: workflow,
        project: workflow.project,
        correlation_id_value: correlation_id_value
      )
    end

    context 'when correlation_id_value is nil' do
      let(:correlation_id_value) { nil }

      it 'is valid' do
        expect(event).to be_valid
      end
    end

    context 'when correlation_id_value is a valid UUID' do
      let(:correlation_id_value) { valid_uuid }

      it 'is valid' do
        expect(event).to be_valid
      end
    end

    context 'when correlation_id_value is an invalid UUID' do
      let(:correlation_id_value) { 'invalid-uuid' }

      it 'is invalid' do
        expect(event).not_to be_valid
        expect(event.errors[:correlation_id_value]).to include('must be a valid UUID')
      end
    end

    context 'when correlation_id_value already exists' do
      let(:correlation_id_value) { valid_uuid }
      let(:event1) { create(:duo_workflows_event, correlation_id_value: correlation_id_value, workflow: workflow) }

      it 'an event with the same uuid in same project is invalid due to uniqueness validation' do
        event2 = build(:duo_workflows_event, correlation_id_value: correlation_id_value, workflow: event1.workflow)
        expect(event2).not_to be_valid
        expect(event2.errors[:correlation_id_value]).to include('has already been taken')
      end

      it 'an event with the same uuid in different projects is valid' do
        event2 = build(:duo_workflows_event, correlation_id_value: correlation_id_value)
        expect(event2).to be_valid
      end
    end

    context 'when correlation_id_value has incorrect format' do
      invalid_formats = {
        'missing_hyphens' => '123e4567e89b12d3a456426614174000',
        'too_short' => '123e4567-e89b-12d3-a456-42661417',
        'too_long' => '123e4567-e89b-12d3-a456-4266141740001',
        'invalid_chars' => '123e4567-e89b-12d3-a456-42661417400g'
      }

      invalid_formats.each do |format_type, value|
        context "with #{format_type}" do
          let(:correlation_id_value) { value }

          it 'is invalid' do
            expect(event).not_to be_valid
            expect(event.errors[:correlation_id_value]).to include('must be a valid UUID')
          end
        end
      end
    end
  end

  describe 'enums' do
    it 'maps event_type to the correct integer values' do
      expect(described_class.event_types[:pause]).to eq(0)
      expect(described_class.event_types[:resume]).to eq(1)
      expect(described_class.event_types[:stop]).to eq(2)
      expect(described_class.event_types[:message]).to eq(3)
      expect(described_class.event_types[:response]).to eq(4)
    end

    it 'maps event_status to the correct integer values' do
      expect(described_class.event_statuses[:queued]).to eq(0)
      expect(described_class.event_statuses[:delivered]).to eq(1)
    end

    it 'returns the correct string for event_type' do
      event = described_class.new(event_type: 'pause')
      expect(event.event_type).to eq('pause')
    end

    it 'returns the correct string for event_status' do
      event = described_class.new(event_status: 'queued')
      expect(event.event_status).to eq('queued')
    end
  end

  describe 'scopes' do
    let!(:queued_event) { create(:duo_workflows_event, workflow: workflow, project: project, event_status: 'queued') }
    let!(:delivered_event) do
      create(:duo_workflows_event, workflow: workflow, project: project, event_status: 'delivered')
    end

    let!(:event_with_correlation_id_value) do
      create(:duo_workflows_event, workflow: workflow, project: project, event_status: 'queued',
        correlation_id_value: '123e4567-e89b-12d3-a456-426614174000')
    end

    it 'returns only queued events' do
      expect(described_class.queued).to include(queued_event)
      expect(described_class.queued).not_to include(delivered_event)
    end

    it 'returns only delivered events' do
      expect(described_class.delivered).to include(delivered_event)
      expect(described_class.delivered).not_to include(queued_event)
    end

    it 'returns appropriate events when correlation_id_value is provided' do
      expect(described_class.with_correlation_id('123e4567-e89b-12d3-a456-426614174000')).to include(
        event_with_correlation_id_value
      )
      expect(described_class.with_correlation_id('invalid_id')).not_to include(event_with_correlation_id_value)
    end
  end
end
