# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceStateEvent do
  let_it_be(:group) { create(:group) }

  subject { build(:resource_state_event) }

  it { is_expected.to belong_to(:epic) }

  describe 'validations' do
    describe 'Issuable validation' do
      it 'is valid if only epic is set' do
        subject.attributes = { epic: build_stubbed(:epic, group: group), issue: nil, merge_request: nil }

        expect(subject).to be_valid
      end

      it 'is invalid if an epic and an issue is set' do
        subject.attributes = {
          epic: build_stubbed(:epic, group: group),
          issue: build_stubbed(:issue),
          merge_request: nil
        }

        expect(subject).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.aliased_for_timebox_report', :freeze_time do
      let!(:event) { create(:resource_state_event, issue: issue) }

      let(:issue) { create(:issue) }
      let(:scope) { described_class.aliased_for_timebox_report.first }

      it 'returns correct values with aliased names', :aggregate_failures do
        expect(scope.event_type).to eq('state')
        expect(scope.id).to eq(event.id)
        expect(scope.issue_id).to eq(event.issue_id)
        expect(scope.value).to eq(issue.state_id)
        expect(scope.action).to be_nil
        expect(scope.created_at).to eq(event.created_at)
      end
    end
  end

  describe 'ensure_namespace_id' do
    context 'when version belongs to an epic' do
      let(:epic) { create(:epic, group: group) }
      let(:state_event) { described_class.new(epic: epic) }

      it 'sets the namespace id from the epic group' do
        expect(state_event.namespace_id).to be_nil

        state_event.valid?

        expect(state_event.namespace_id).to eq(epic.group_id)
      end
    end
  end
end
