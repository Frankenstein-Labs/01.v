# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ProcessBulkDismissedEventsWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:vulnerabilities) do
    create_list(:vulnerability, 2, :with_findings, :detected, :high_severity, project: project)
  end

  let(:comment) { "i prefer lowercase." }
  let(:dismissal_reason) { 'used_in_tests' }
  let(:note_with_comment) do
    "changed vulnerability status to Dismissed: " \
      "Used In Tests with the following comment: \"#{comment}\""
  end

  let(:bulk_dismissed_event) { create_bulk_dismissed_event(vulnerabilities) }

  def create_bulk_dismissed_event(vulnerabilities)
    ::Vulnerabilities::BulkDismissedEvent.new(data: {
      vulnerabilities: vulnerabilities.map do |vulnerability|
        {
          vulnerability_id: vulnerability.id,
          project_id: project.id,
          namespace_id: vulnerability.project.project_namespace_id,
          dismissal_reason: dismissal_reason,
          comment: comment,
          user_id: user.id
        }
      end
    })
  end

  subject(:use_event) do
    ->(event) { consume_event(subscriber: described_class, event: event) }
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it 'inserts a system note for each vulnerability' do
    # Stub the random component of discussion_id generation so the persisted
    # discussion_id is deterministic and can be asserted exactly.
    allow(SecureRandom).to receive(:hex).and_return('fixed-discussion-id-seed')

    expect { use_event.call(bulk_dismissed_event) }
      .to change { Note.count }.by(2)
      .and change { SystemNoteMetadata.count }.by(2)

    notes = Note.where(project: project).order(:id)
    metadata = SystemNoteMetadata.where(note: notes).order(:note_id)

    expect(notes.count).to eq(2)
    expect(metadata.count).to eq(2)

    aggregate_failures 'note attributes' do
      notes.zip(vulnerabilities).each do |note, vulnerability|
        expect(note).to have_attributes(
          noteable: vulnerability,
          author: user,
          project: project,
          namespace_id: nil,
          note: note_with_comment
        )
      end
    end

    aggregate_failures 'discussion_id is derived from the correct noteable' do
      nil_discussion_id = Discussion.discussion_id(Note.new(
        noteable_id: nil,
        noteable_type: "Vulnerability"
      ))

      notes.zip(vulnerabilities).each do |note, vulnerability|
        expect(note.discussion_id).to eq(Discussion.discussion_id(Note.new(
          noteable_id: vulnerability.id,
          noteable_type: "Vulnerability"
        )))

        expect(note.discussion_id).not_to eq(nil_discussion_id)
      end
    end

    aggregate_failures 'system note metadata attributes' do
      metadata.zip(notes).each do |meta, note|
        expect(meta).to have_attributes(
          note_id: note.id,
          action: "vulnerability_dismissed"
        )
      end
    end
  end

  it 'triggers webhook events for each vulnerability' do
    2.times do
      expect_next_found_instance_of(Vulnerability) do |found_vulnerability|
        expect(found_vulnerability).to receive(:trigger_webhook_event)
      end
    end

    use_event.call(bulk_dismissed_event)
  end

  it 'avoids N+1 queries', :use_sql_query_cache do
    control_event = create_bulk_dismissed_event(vulnerabilities)
    control = ActiveRecord::QueryRecorder.new(skip_cached: false) { use_event.call(control_event) }

    additional_vulnerabilities = create_list(:vulnerability, 2, :with_findings, :detected, :high_severity,
      project: project)
    test_event = create_bulk_dismissed_event(vulnerabilities + additional_vulnerabilities)

    expect { use_event.call(test_event) }.to issue_same_number_of_queries_as(control)
  end
end
