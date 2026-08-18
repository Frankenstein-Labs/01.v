# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['BranchRule'], feature_category: :source_code_management do
  include GraphqlHelpers

  subject { described_class }

  let_it_be(:fields) { %i[approval_rules external_status_checks is_group_level] }

  it { is_expected.to have_graphql_fields(fields).at_least }

  describe '#is_group_level' do
    let_it_be(:project, freeze: false) { create(:project, :in_group) }
    let_it_be(:current_user) { create(:user, maintainer_of: project) }

    subject(:resolved_field) do
      resolve_field(:is_group_level, branch_rule, current_user: current_user, object_type: described_class)
    end

    context 'with a project-level branch rule' do
      let(:branch_rule) { Projects::BranchRule.new(project, create(:protected_branch, project: project)) }

      it { is_expected.to be(false) }
    end

    context 'with a group-level branch rule' do
      let(:branch_rule) do
        Projects::BranchRule.new(project, create(:protected_branch, :group_level, group: project.group))
      end

      it { is_expected.to be(true) }
    end

    context 'with a custom rule that has no protected branch' do
      let(:branch_rule) { Projects::AllBranchesRule.new(project) }

      it { is_expected.to be(false) }
    end
  end
end
