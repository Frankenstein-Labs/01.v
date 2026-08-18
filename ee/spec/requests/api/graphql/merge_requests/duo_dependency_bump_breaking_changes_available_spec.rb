# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying mergeRequest.duoDependencyBumpBreakingChangesAvailable',
  feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          mergeRequest(iid: "#{merge_request.iid}") {
            duoDependencyBumpBreakingChangesAvailable
          }
        }
      }
    )
  end

  subject(:available) do
    GitlabSchema.execute(query, context: { current_user: current_user })
      .as_json.dig('data', 'project', 'mergeRequest', 'duoDependencyBumpBreakingChangesAvailable')
  end

  context 'when the flow is available for the merge request' do
    before do
      allow_next_found_instance_of(MergeRequest) do |found_mr|
        allow(found_mr).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
      end
    end

    it { is_expected.to be(true) }
  end

  context 'when the flow is not available for the merge request' do
    before do
      allow_next_found_instance_of(MergeRequest) do |found_mr|
        allow(found_mr).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(false)
      end
    end

    it { is_expected.to be(false) }
  end

  context 'when the current user cannot read the merge request' do
    let(:current_user) { create(:user) }

    before do
      # Even if the flow would be available, an unauthorized caller must not see it.
      allow_next_found_instance_of(MergeRequest) do |found_mr|
        allow(found_mr).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
      end
    end

    it { is_expected.to be_nil }
  end

  context 'when the request is unauthenticated' do
    let(:current_user) { nil }

    before do
      # Even if the flow would be available, an anonymous caller must not see it.
      allow_next_found_instance_of(MergeRequest) do |found_mr|
        allow(found_mr).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
      end
    end

    it { is_expected.to be_nil }
  end
end
