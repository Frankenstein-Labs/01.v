# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkCreateRedetectedNotesService, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: create(:user)) }
  let(:time) { Time.current }
  let(:timestamp) { time.iso8601 }

  let_it_be(:vulnerability) do
    create(:vulnerability, project: project)
  end

  let(:vulnerabilities_data) do
    [{
      vulnerability_id: vulnerability.id,
      pipeline_id: pipeline.id,
      timestamp: timestamp
    }]
  end

  subject(:execute) { described_class.new(vulnerabilities_data).execute }

  it 'inserts a system note for redetected vulnerability', :aggregate_failures, :freeze_time do
    execute

    path = "/#{pipeline.project.full_path}/-/pipelines/#{pipeline.id}"
    link = %r{\[#{pipeline.id}\]\(.*#{path}\)}
    expected_note = %r{changed vulnerability status to Needs Triage because it was redetected in pipeline #{link}}

    note = Note.find_by(noteable_type: vulnerability.class.name, noteable_id: vulnerability.id)

    expect(note).to be_valid
    expect(note.note).to match(expected_note)
    expect(note.created_at).to be_like_time(time)
    expect(note.updated_at).to be_like_time(time)
    expect(note).to have_attributes(
      author_id: pipeline.user_id,
      project_id: pipeline.project_id,
      namespace_id: nil,
      noteable: vulnerability,
      system: true
    )

    expect(note.system_note_metadata).to be_valid
    expect(note.system_note_metadata).to have_attributes(
      action: 'vulnerability_detected'
    )
    expect(note.system_note_metadata.created_at).to be_like_time(time)
    expect(note.system_note_metadata.updated_at).to be_like_time(time)
  end

  it 'does not execute N+1 queries' do
    control = ActiveRecord::QueryRecorder.new { described_class.new(vulnerabilities_data).execute }

    new_event = {
      vulnerability_id: create(:vulnerability, project: project).id,
      pipeline_id: create(:ci_pipeline, project: project).id,
      timestamp: Time.current.iso8601
    }

    new_data = vulnerabilities_data.append(new_event)

    expect { described_class.new(new_data).execute }.not_to exceed_query_limit(control)
  end
end
