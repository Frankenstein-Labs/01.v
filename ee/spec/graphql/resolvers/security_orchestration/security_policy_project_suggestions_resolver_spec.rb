# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::SecurityOrchestration::SecurityPolicyProjectSuggestionsResolver, feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:top_level_group) { create(:group, name: "alpha") } # alpha
  let_it_be(:subgroup) { create(:group, parent: top_level_group, name: "beta") } # alpha/beta

  let_it_be_with_refind(:policy_project) do
    create(:project, group: top_level_group, name: "policy-project") # alpha/policy-project
  end
  let_it_be(:project) { create(:project, group: subgroup, path: "example-project") } # alpha/beta/example-project

  let_it_be(:other_group) { create(:group, :public, name: "other") } # other
  let_it_be(:other_project) { create(:project, :public, group: other_group, path: "alpha") } # other/alpha

  let_it_be(:user) { create(:user, developer_of: top_level_group) }
  let_it_be(:suggestion_limit) { ::Security::SecurityPolicyProjectsFinder::SUGGESTION_LIMIT }
  let_it_be(:search_space_limit) { ::Security::SecurityPolicyProjectsFinder::SEARCH_SPACE_LIMIT }

  before_all do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace_id: top_level_group.id,
      security_policy_management_project_id: policy_project.id)
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  subject(:suggestions) do
    resolve(
      described_class,
      obj: container,
      args: args,
      ctx: { current_user: user }
    )
  end

  describe 'max_page_size' do
    subject(:size) { described_class.max_page_size }

    it { is_expected.to be(::Security::SecurityPolicyProjectsFinder::SUGGESTION_LIMIT) }
  end

  shared_examples 'suggests security policy projects' do
    context 'when SaaS' do
      let(:args) { { search: "project" } }

      it { is_expected.to contain_exactly(policy_project, project) }

      include_examples "excludes archived and projects pending deletion"

      context 'when exceeding suggestion limit' do
        let(:suggestion_limit) { 3 }
        let(:args) { { search: "alpha" } }

        before do
          stub_const('::Security::SecurityPolicyProjectsFinder::SUGGESTION_LIMIT', suggestion_limit)

          build_list(:project, suggestion_limit + 1) do |project, i|
            project.group = top_level_group
            project.path = "alpha-#{i}"
            project.save!
          end

          user.refresh_authorized_projects
        end

        it 'limits suggestion' do
          expect(suggestions.to_a.size).to be(suggestion_limit)
        end

        describe 'ordering' do
          let(:args) { { search: "alpha-" } }

          it 'orders by string similiarity' do
            expect(suggestions.first.full_path).to eq("alpha/alpha-3")
          end
        end
      end

      context 'when restricted to already linked policy projects' do
        let(:args) { { search: "project", only_linked: true } }

        it { is_expected.to contain_exactly(policy_project) }

        include_examples "excludes archived and projects pending deletion"
      end
    end

    context 'when self-managed' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      let(:args) { { search: "alpha" } }

      it { is_expected.to contain_exactly(policy_project, project, other_project) }

      include_examples "excludes archived and projects pending deletion"

      context 'with exact match' do
        let(:args) { { search: project.full_path } }

        before do
          expect_next_instance_of(::Security::SecurityPolicyProjectsFinder) do |service|
            allow(service).to receive(:global_matching_projects) \
                                .and_return(Project.none)
                                .once
          end
        end

        it 'includes the exact match' do
          expect(suggestions).to contain_exactly(project)
        end
      end

      context 'when restricted to already linked policy projects' do
        let(:args) { { search: "alpha", only_linked: true } }

        it { is_expected.to contain_exactly(policy_project) }

        include_examples "excludes archived and projects pending deletion"
      end
    end
  end

  describe 'suggestions for a group' do
    let(:container) { subgroup }

    include_examples 'suggests security policy projects'
  end

  describe 'suggestions for a project' do
    let(:container) { project }

    include_examples 'suggests security policy projects'
  end
end
