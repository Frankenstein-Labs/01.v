# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Projects::BranchRulesResolver, feature_category: :source_code_management do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  before_all do
    project.add_maintainer(current_user)
  end

  describe '#resolve' do
    subject(:resolved) do
      field = ::Types::BaseField.new(
        name: 'branch_rules',
        owner: resolver_parent,
        resolver_class: described_class,
        connection_extension: Gitlab::Graphql::Extensions::ForwardOnlyExternallyPaginatedArrayExtension,
        null: true,
        max_page_size: 100,
        default_page_size: 20,
        calls_gitaly: true
      )

      resolve_field(field, project, args: {}, object_type: resolver_parent, schema: GitlabSchema)
    end

    it 'includes all_protected_branches rule' do
      expect(resolved.items.first).to be_a(Projects::AllBranchesRule)
    end

    it 'includes protected branches' do
      expect(resolved.items.last).to be_a(Projects::BranchRule)
    end
  end
end
