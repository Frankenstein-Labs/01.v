# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::VulnerabilitiesService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:author) { create(:user) }

  let(:vulnerability) { create(:vulnerability, project: project) }
  let(:noteable) { vulnerability }
  let(:service) { described_class.new(noteable: vulnerability, container: project, author: author) }

  describe '#change_vulnerability_state' do
    subject { service.change_vulnerability_state }

    context 'when no state transition is present' do
      subject { service.change_vulnerability_state }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { "vulnerability_detected" }
      end

      it 'creates the note text correctly' do
        expect(subject.note).to eq("changed vulnerability status to Detected")
      end
    end

    {
      'dismissed' => 'resolved',
      'resolved' => 'confirmed',
      'confirmed' => 'dismissed'
    }.each do |from_state, to_state|
      context "state changed from #{from_state} to #{to_state}" do
        let!(:state_transition) do
          create(:vulnerability_state_transition, vulnerability: vulnerability,
            from_state: from_state, to_state: to_state, comment: nil)
        end

        it_behaves_like 'a system note', exclude_project: true do
          let(:action) { "vulnerability_#{to_state}" }
        end

        it 'creates the note text correctly' do
          expect(subject.note).to eq("changed vulnerability status from #{from_state.titleize} to #{to_state.titleize}")
        end
      end
    end

    context 'when dismissal reason is present and state is dismissed' do
      subject { service.change_vulnerability_state }

      let!(:state_transition) do
        create(:vulnerability_state_transition, vulnerability: vulnerability, to_state: 'dismissed',
          dismissal_reason: :false_positive, comment: nil)
      end

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { "vulnerability_dismissed" }
      end

      it 'creates the note text correctly' do
        expect(subject.note).to eq("changed vulnerability status from Detected to Dismissed: False Positive")
      end
    end

    context 'when dismissal reason is present and state is not dismissed' do
      subject { service.change_vulnerability_state }

      let!(:state_transition) do
        create(:vulnerability_state_transition, vulnerability: vulnerability, from_state: 'resolved',
          to_state: 'detected', dismissal_reason: :false_positive, comment: nil)
      end

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { "vulnerability_detected" }
      end

      it 'creates the note text correctly' do
        expect(subject.note).to eq("reverted vulnerability status from Resolved to Detected")
      end
    end

    context 'when the state transition comment exists' do
      let!(:state_transition) do
        create(:vulnerability_state_transition, vulnerability: vulnerability, from_state: 'resolved',
          to_state: 'detected', comment: 'test')
      end

      it 'creates the note text correctly' do
        expect(subject.note).to eq(
          'reverted vulnerability status from Resolved to Detected with the following comment: "test"'
        )
      end
    end

    context 'when body provided' do
      subject { service.change_vulnerability_state(comment) }

      let!(:state_transition) do
        create(:vulnerability_state_transition, vulnerability: vulnerability, from_state: 'resolved',
          to_state: 'detected')
      end

      let(:comment) { 'This vulnerability type has been deprecated' }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { "vulnerability_detected" }
      end

      it 'creates the note text correctly' do
        expect(subject.note).to eq(comment)
      end
    end
  end

  describe '#formatted_note for severity override' do
    subject(:formatted_note) do
      described_class.formatted_note(
        transition: 'changed', to_value: to_severity, reason: nil, comment: comment,
        attribute: 'severity', from_value: from_severity
      )
    end

    let(:from_severity) { 'low' }
    let(:to_severity) { 'critical' }
    let(:comment) { nil }

    context 'when no comment is passed' do
      it 'returns the note text correctly' do
        expect(formatted_note).to eq("changed vulnerability severity from #{from_severity.titleize} " \
          "to #{to_severity.titleize}")
      end
    end

    context 'when comment is passed' do
      let(:comment) { 'Test comment' }

      it 'returns the note text correctly' do
        expect(formatted_note).to eq("changed vulnerability severity from #{from_severity.titleize} " \
          "to #{to_severity.titleize} with the following comment: \"Test comment\"")
      end
    end
  end
end
