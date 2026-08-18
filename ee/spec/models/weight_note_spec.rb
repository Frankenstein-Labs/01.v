# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WeightNote, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let(:author) { create(:user) }
  let_it_be(:project) { create(:project, :small_repo) }
  let(:noteable) { create(:issue, author: author, project: project) }
  let(:event) { create(:resource_weight_event, issue: noteable) }

  subject { described_class.from_event(event, resource: noteable, resource_parent: project) }

  it_behaves_like 'a synthetic note', 'weight'

  it 'creates the expected note' do
    expect(subject.created_at).to eq(event.created_at)
    expect(subject.updated_at).to eq(event.created_at)
  end

  describe '#note' do
    where(
      :html,
      :previous_weight,
      :weight,
      :expected_note
    ) do
      false | nil | 1   | 'set weight to 1'
      false | 1   | 2   | 'changed weight to 2 from 1'
      false | 1   | nil | 'removed weight of 1'
      false | nil | nil | 'removed weight'
    end

    with_them do
      let(:event) do
        create(
          :resource_weight_event,
          issue: noteable,
          previous_weight: previous_weight,
          weight: weight
        )
      end

      subject(:note) do
        described_class.from_event(event, resource: noteable, resource_parent: project).note
      end

      it 'returns the expected note' do
        expect(note).to eq(expected_note)
      end
    end
  end

  describe '#note_html' do
    where(
      :html,
      :previous_weight,
      :weight,
      :expected_note
    ) do
      true  | nil | 1   | '<p dir="auto">set weight to <strong>1</strong></p>'
      true  | 1   | 2   | '<p dir="auto">changed weight to <strong>2</strong> from <strong>1</strong></p>'
      true  | 1   | nil | '<p dir="auto">removed weight of <strong>1</strong></p>'
      true  | nil | nil | '<p dir="auto">removed weight</p>'
    end

    with_them do
      let(:event) do
        create(
          :resource_weight_event,
          issue: noteable,
          previous_weight: previous_weight,
          weight: weight
        )
      end

      subject(:note_html) do
        described_class.from_event(event, resource: noteable, resource_parent: project).note_html
      end

      it 'returns the expected note' do
        expect(note_html).to eq(expected_note)
      end
    end
  end
end
