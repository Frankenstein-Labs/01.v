# frozen_string_literal: true

require "spec_helper"

RSpec.describe Epics::DiscussionEntity, feature_category: :team_planning do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, namespace: group) }

  let(:note) { build_stubbed(:discussion_note_on_merge_request, project: project) }
  let(:discussion) { note.discussion }
  let(:controller) { instance_double(ApplicationController) }

  # rubocop: disable RSpec/VerifiedDoubles -- methods on EntityRequest are dynamic created
  let(:request) do
    double(
      'request',
      note_entity: ProjectNoteEntity,
      current_user: user,
      noteable: note.noteable
    )
  end
  # rubocop: enable RSpec/VerifiedDoubles

  let(:entity) { described_class.new(discussion, request: request, context: controller) }

  subject(:json) { entity.as_json }

  before do
    allow(note).to receive(:update_columns)
    allow(controller).to receive(:render_to_string)
  end

  it 'exposes correct attributes' do
    expect(json.keys).to contain_exactly(
      :commit_id,
      :confidential,
      :diff_discussion,
      :discussion_path,
      :expanded,
      :for_commit,
      :id,
      :individual_note,
      :notes,
      :project_id,
      :reply_id,
      :resolvable,
      :resolve_path,
      :resolve_with_issue_path,
      :resolved,
      :resolved_at,
      :resolved_by,
      :resolved_by_push
    )
  end

  it 'always returns expanded? as true' do
    expect(json[:expanded]).to eq(true)
  end

  it 'always returns resolved? as false' do
    expect(json[:resolved]).to eq(false)
  end

  it 'always returns resolvable? as false' do
    expect(json[:resolvable]).to eq(false)
  end

  context 'when discussion is not expanded' do
    include Gitlab::Routing

    # rubocop: disable RSpec/FactoryBot/AvoidCreate -- the internals of the note is used to build the route in test
    let(:note) { create(:discussion_note, :on_work_item, :resolved) }
    # rubocop: enable RSpec/FactoryBot/AvoidCreate

    it 'exposes correct attributes' do
      expect(json.keys).to contain_exactly(
        :commit_id,
        :confidential,
        :diff_discussion,
        :discussion_path,
        :expanded,
        :for_commit,
        :id,
        :individual_note,
        :notes,
        :project_id,
        :reply_id,
        :resolvable,
        :resolve_path,
        :resolved,
        :resolved_at,
        :resolved_by,
        :resolved_by_push,
        :truncated_diff_lines_path
      )

      expect(json[:truncated_diff_lines_path]).to eq(
        discussions_group_epic_path(note.noteable.namespace, note.noteable)
      )
    end
  end
end
