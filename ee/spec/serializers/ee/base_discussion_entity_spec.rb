# frozen_string_literal: true

require "spec_helper"

RSpec.describe BaseDiscussionEntity, feature_category: :shared do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:namespace) { build_stubbed(:namespace) }
  let_it_be(:work_item) { build_stubbed(:work_item, :epic, namespace: namespace) }
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:note, freeze: false) do
    build_stubbed(:discussion_note, :resolved, project: work_item.project, noteable: work_item)
  end

  let(:request) { EntityRequest.new(note_entity: EpicNoteEntity) }
  let(:controller) { instance_double(Groups::EpicsController) }
  let(:entity) { described_class.new(discussion, request: request, context: controller) }
  let(:discussion) { note.discussion }

  subject(:json) { entity.as_json }

  context 'as json' do
    context 'when discussion is not expanded' do
      include Gitlab::Routing

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
          discussions_group_epic_path(work_item.namespace, work_item)
        )
      end
    end
  end
end
