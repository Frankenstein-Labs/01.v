# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::MergeRequestDependency, feature_category: :code_review_workflow do
  let_it_be(:project) { create(:project) }
  let_it_be(:private_project) { create(:project, :private) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:other_merge_request) do
    create(:merge_request, source_project: private_project, target_project: private_project)
  end

  let_it_be(:user) { create(:user) }

  let_it_be(:block) do
    merge_request.blocks_as_blockee.create!(blocking_merge_request: other_merge_request)
  end

  let_it_be(:entity) { described_class.new(merge_request.blocks_as_blockee.first, current_user: user) }

  subject(:entity_json) { entity.as_json }

  before_all do
    project.add_maintainer(user)
  end

  context 'when the user has access to the MRs' do
    before_all do
      private_project.add_maintainer(user)
    end

    it "returns expected data" do
      aggregate_failures do
        expect(entity_json[:id]).to eq(block.id)
        expect(entity_json[:blocked_merge_request][:id]).to eq(block.blocked_merge_request.id)
        expect(entity_json[:blocking_merge_request][:id]).to eq(block.blocking_merge_request.id)
        expect(entity_json[:project_id]).to eq(block.blocking_merge_request.project_id)
      end
    end
  end

  context 'when the user does not have access to the blocking MR' do
    it "returns expected data" do
      aggregate_failures do
        expect(entity_json[:id]).to eq(block.id)
        expect(entity_json[:blocked_merge_request][:id]).to eq(block.blocked_merge_request.id)
        expect(entity_json[:blocking_merge_request]).to be_nil
        expect(entity_json[:project_id]).to eq(block.blocking_merge_request.project_id)
      end
    end
  end
end
