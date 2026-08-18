# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityPolicyProjectsFinder, "#execute", feature_category: :security_policy_management do
  let_it_be(:top_level_group) { create(:group, name: "alpha") } # alpha
  let_it_be(:subgroup_a) { create(:group, parent: top_level_group, name: "beta") } # alpha/beta
  let_it_be(:subgroup_b) { create(:group, parent: top_level_group, name: "gamma") } # alpha/gamma

  let_it_be_with_refind(:policy_project) do
    create(:project, group: top_level_group, name: "policy-project") # alpha/policy-project
  end
  let_it_be(:project_a) { create(:project, group: subgroup_a, path: "project-a") } # alpha/beta/project-a
  let_it_be(:project_b) { create(:project, group: subgroup_b, path: "project-b") } # alpha/gamma/project-b

  let_it_be(:other_group) { create(:group, :public, name: "other") }
  let_it_be(:other_project) { create(:project, :public, group: other_group, path: "alpha") }

  let_it_be(:user) { create(:user, developer_of: top_level_group) }

  let(:feature_enabled) { true }

  before_all do
    create(
      :security_orchestration_policy_configuration,
      :namespace,
      namespace_id: top_level_group.id,
      security_policy_management_project_id: policy_project.id)
  end

  subject(:suggestions) { described_class.new(container: container, current_user: user, params: params).execute }

  shared_examples 'suggests security policy projects' do
    before do
      stub_licensed_features(security_orchestration_policies: feature_enabled)
    end

    shared_examples "returns early without licensed feature" do
      context "without licensed feature" do
        let(:feature_enabled) { false }

        it { is_expected.to be_empty }
      end
    end

    context 'when searching within root container' do
      let(:params) { { search: "project", search_globally: false } }

      it { is_expected.to contain_exactly(policy_project, project_a, project_b) }

      include_examples "excludes archived and projects pending deletion"
      include_examples "returns early without licensed feature"

      context 'when exceeding suggestion limit' do
        let(:suggestion_limit) { 3 }
        let(:params) { { search: "alpha", search_globally: false } }

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
          expect(suggestions.to_a.size).to be(described_class::SUGGESTION_LIMIT)
        end

        describe 'ordering' do
          let(:params) { { search: "alpha-", search_globally: false } }

          it 'orders by string similiarity' do
            expect(suggestions.first.full_path).to eq("alpha/alpha-3")
          end
        end
      end

      context 'when restricted to already linked policy projects' do
        let(:params) { { search: "project", search_globally: false, only_linked: true } }

        it { is_expected.to contain_exactly(policy_project) }

        include_examples "excludes archived and projects pending deletion"
        include_examples "returns early without licensed feature"
      end
    end

    context 'when searching globally' do
      let(:params) { { search: "alpha", search_globally: true } }

      it { is_expected.to contain_exactly(policy_project, project_a, project_b, other_project) }

      include_examples "excludes archived and projects pending deletion"
      include_examples "returns early without licensed feature"

      context 'with exact match' do
        let(:params) { { search: project_a.full_path, search_globally: true } }

        before do
          expect_next_instance_of(described_class) do |service|
            allow(service).to receive(:global_matching_projects) \
                                .and_return(Project.none)
                                .once
          end
        end

        it 'includes the exact match' do
          expect(suggestions).to contain_exactly(project_a)
        end
      end

      context 'when restricted to already linked policy projects' do
        let(:params) { { search: "alpha", search_globally: true, only_linked: true } }

        it { is_expected.to contain_exactly(policy_project) }

        include_examples "excludes archived and projects pending deletion"
        include_examples "returns early without licensed feature"
      end
    end

    context 'with unrecognized params' do
      let(:params) { { foo: :bar } }

      it { is_expected.to be_empty }
    end
  end

  describe 'suggestions for a group' do
    let(:container) { subgroup_a }

    include_examples 'suggests security policy projects'
  end

  describe 'suggestions for a project' do
    let(:container) { project_a }

    include_examples 'suggests security policy projects'
  end
end
