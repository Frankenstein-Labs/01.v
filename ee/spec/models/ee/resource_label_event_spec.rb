# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ResourceLabelEvent, type: :model do
  subject { build(:resource_label_event) }

  let_it_be(:epic) { create(:epic) }

  describe 'validations' do
    describe 'Issuable validation' do
      it 'is valid if only epic_id is set' do
        subject.attributes = { epic: epic, issue: nil, merge_request: nil }

        expect(subject).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'ensure_namespace_id' do
      context 'when event belongs to an epic' do
        let(:label_event) { described_class.new(epic: epic) }

        it 'sets the namespace id from the epic group' do
          expect(label_event.namespace_id).to be_nil

          label_event.valid?

          expect(label_event.namespace_id).to eq(epic.group_id)
        end
      end
    end
  end
end
