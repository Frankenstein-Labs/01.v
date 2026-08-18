# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::CommitAiEntity, feature_category: :ai_abstraction_layer do
  let_it_be(:user, freeze: false) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let_it_be(:project, freeze: false) { create(:project, :public, :repository) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
  let_it_be(:commit, freeze: false) { project.commit }
  let(:diffs) { commit.raw_diffs.as_json }
  let(:notes_limit) { 1000 }

  let(:entity) do
    described_class.new(
      commit,
      user: user,
      resource: Ai::AiResource::Commit.new(user, commit),
      notes_limit: notes_limit,
      request: EntityRequest.new(project: project)
    )
  end

  subject(:basic_entity) { entity.as_json }

  it "exposes basic entity fields" do
    expected_fields = %i[
      id short_id created_at parent_ids title message author_name author_email authored_date
      committer_name committer_email committed_date trailers extended_trailers web_url author
      author_gravatar_url commit_url commit_path commit_comments diffs
    ]

    is_expected.to include(*expected_fields)
  end

  context "with commit comments on the entity" do
    let!(:note) { create(:note_on_commit, commit_id: commit.id, project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it
    let!(:note2) { create(:note_on_commit, commit_id: commit.id, project: project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- we need to create it

    it "exposes the comments" do
      expect(basic_entity[:commit_comments]).to match_array([note.note, note2.note])
    end
  end

  context "with diffs on the entity" do
    it "exposes the diffs information" do
      expect(basic_entity[:diffs]).to eq(diffs)
    end
  end
end
