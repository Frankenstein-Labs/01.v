# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::MergeRequestAiEntity, feature_category: :ai_abstraction_layer do # rubocop:disable RSpec/SpecFilePathFormat -- path is correct
  let_it_be(:user) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it
  let_it_be(:merge_request) { create(:merge_request) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it
  let(:notes_limit) { 1000 }

  let(:entity) do
    described_class.new(merge_request,
      user: user,
      resource: Ai::AiResource::MergeRequest.new(user, merge_request),
      notes_limit: notes_limit)
  end

  subject(:basic_entity) { entity.as_json }

  before do
    merge_request.project.add_developer(user)
  end

  it "exposes basic entity fields" do
    expected_fields = %i[
      merged_by merge_user merged_at closed_by closed_at target_branch user_notes_count upvotes downvotes
      author assignees assignee reviewers source_project_id target_project_id labels draft work_in_progress
      milestone merge_when_pipeline_succeeds merge_status detailed_merge_status sha merge_commit_sha
      squash_commit_sha discussion_locked should_remove_source_branch force_remove_source_branch prepared_at
      reference references web_url time_stats squash task_completion_status has_conflicts blocking_discussions_resolved
      imported imported_from
    ]

    is_expected.to include(*expected_fields)
  end

  context "with mr comments on the entity" do
    let!(:note) { create(:note_on_merge_request, noteable: merge_request, project: merge_request.project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it
    let!(:note2) { create(:note_on_merge_request, noteable: merge_request, project: merge_request.project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it

    it "exposes the number of comments" do
      expect(basic_entity[:mr_comments]).to match_array([note.note, note2.note])
    end
  end

  context "with diff on the entity" do
    it "exposes the diff information" do
      allow(Gitlab::Llm::Utils::MergeRequestTool).to receive(:extract_diff_for_duo_chat)
        .and_return("--- CHANGELOG\n+++ CHANGELOG\n\n+Some changes\n")

      expect(basic_entity[:diff]).to eq("--- CHANGELOG\n+++ CHANGELOG\n\n+Some changes\n")
    end
  end

  context "with mr comments and diff on the entity" do
    let!(:note) { create(:note_on_merge_request, noteable: merge_request, project: merge_request.project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need create it

    before do
      allow(Gitlab::Llm::Utils::MergeRequestTool).to receive(:extract_diff_for_duo_chat)
        .and_return("--- CHANGELOG\n+++ CHANGELOG\n\n+Some changes\n")
    end

    it "exposes the number of comments" do
      expect(basic_entity[:mr_comments]).to match_array([note.note])
    end

    it "exposes the diff information" do
      expect(basic_entity[:diff]).to eq("--- CHANGELOG\n+++ CHANGELOG\n\n+Some changes\n")
    end

    it "ensures diff comes before mr_comments if serialized" do
      json = entity.as_json
      keys = json.keys
      mr_comments_index = keys.index(:mr_comments)
      diff_index = keys.index(:diff)

      expect(diff_index).to be < mr_comments_index
    end
  end

  context 'when is_duo_code_review option is provided' do
    let(:entity) do
      described_class.new(merge_request,
        user: user,
        resource: Ai::AiResource::MergeRequest.new(user, merge_request),
        notes_limit: notes_limit,
        is_duo_code_review: true)
    end

    it 'passes is_duo_code_review to notes_with_limit' do
      resource = entity.options[:resource]

      expect(resource).to receive(:notes_with_limit)
                            .with(notes_limit: notes_limit / 2, is_duo_code_review: true)
                            .and_return([])

      entity.as_json[:mr_comments]
    end
  end
end
