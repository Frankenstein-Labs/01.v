# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying duoDependencyBumpBreakingChangesAvailable', feature_category: :continuous_integration do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }

  let(:query) do
    %(
      query {
        project(fullPath: "#{project.full_path}") {
          duoDependencyBumpBreakingChangesAvailable
        }
      }
    )
  end

  subject(:available) do
    GitlabSchema.execute(query, context: { current_user: current_user })
      .as_json.dig('data', 'project', 'duoDependencyBumpBreakingChangesAvailable')
  end

  context 'when the flow is available for the project' do
    before do
      allow_next_found_instance_of(Project) do |found_project|
        allow(found_project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(true)
      end
    end

    it { is_expected.to be(true) }
  end

  context 'when the flow is not available for the project' do
    before do
      allow_next_found_instance_of(Project) do |found_project|
        allow(found_project).to receive(:duo_dependency_bump_breaking_changes_available?).and_return(false)
      end
    end

    it { is_expected.to be(false) }
  end
end
