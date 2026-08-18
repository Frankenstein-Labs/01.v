# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ProjectSetLocked', feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }

  before do
    stub_licensed_features(file_locks: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :create_path_lock do
    let(:user) { create(:user, developer_of: project) }
    let(:boundary_object) { project }

    let(:mutation) do
      graphql_mutation(
        :project_set_locked,
        { project_path: project.full_path, file_path: 'README.md', lock: true },
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
