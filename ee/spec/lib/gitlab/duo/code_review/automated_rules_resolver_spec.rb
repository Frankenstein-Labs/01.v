# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::CodeReview::AutomatedRulesResolver, feature_category: :duo_code_review do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { build_stubbed(:user) }
  let(:group) { build_stubbed(:group) }
  let(:subgroup) { build_stubbed(:group, parent: group) }
  let(:project) do
    build_stubbed(:project, :with_code_review_automated_rules, group: subgroup, automated_rules: project_rules)
  end

  let(:resolver) { described_class.new(project, user) }
  let(:ancestor_duo_template_projects) { [] }

  let(:target_branch) { 'master' }
  let(:source_branch) { 'feature' }
  let(:author_username) { 'alice' }
  let(:author) { instance_double(User, username: author_username) }
  let(:project_rules) { nil }

  let(:merge_request) do
    instance_double(
      MergeRequest,
      target_branch: target_branch,
      source_branch: source_branch,
      author: author
    )
  end

  before do
    allow(resolver).to receive(:ancestor_duo_template_projects).and_return(ancestor_duo_template_projects)
    allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
    allow(::Gitlab::CurrentSettings.current_application_settings)
      .to receive(:duo_template_project).and_return(nil)
  end

  def rules_yaml(**filters)
    { 'exclude' => filters.transform_keys(&:to_s).transform_values { |patterns| Array(patterns) } }.to_yaml
  end

  def template_project(rules, group: nil)
    build_stubbed(:project, :with_code_review_automated_rules, group: group, automated_rules: rules)
  end

  describe '#excluded?' do
    subject(:excluded) { resolver.excluded?(merge_request) }

    context 'when there are no rules to match against' do
      where(:rules_content) do
        [
          nil,
          "foo: bar\n",
          '',
          "exclude:\n  target_branches:\n",
          "exclude: []\n",
          "exclude: true\n",
          "exclude:\n  target_branches:\n    foo: bar\n"
        ]
      end

      with_them do
        let(:project_rules) { rules_content }

        it { is_expected.to be(false) }
      end
    end

    context 'when normalizing rule patterns' do
      context 'when a rule value is a string' do
        let(:project_rules) { "exclude:\n  authors: alice\n" }

        it { is_expected.to be(true) }
      end

      context 'when a rule value is a numeric scalar' do
        let(:author_username) { '123' }
        let(:project_rules) { "exclude:\n  authors: 123\n" }

        it { is_expected.to be(true) }
      end

      context 'when a rule value contains strings and invalid values' do
        let(:project_rules) do
          <<~YAML
            exclude:
              authors:
                - foo:
                    bar: baz
                - alice
          YAML
        end

        it 'ignores invalid values and matches valid strings' do
          expect(excluded).to be(true)
        end
      end
    end

    context 'when matching a project rule against the merge request' do
      where(:filter, :pattern, :value, :expected) do
        :target_branches | 'master'     | 'master'              | true
        :target_branches | 'master'     | 'develop'             | false
        :source_branches | 'feature'    | 'feature'             | true
        :source_branches | 'renovate/*' | 'renovate/lodash-4.x' | true
        :source_branches | 'renovate/*' | 'renovate/npm/lodash' | true
        :source_branches | 'renovate/*' | 'feature/foo'         | false
        :authors         | 'alice'      | 'alice'               | true
        :authors         | 'alice'      | 'bob'                 | false
      end

      with_them do
        let(:project_rules) { rules_yaml(filter => pattern) }
        let(:target_branch) { filter == :target_branches ? value : 'unmatched' }
        let(:source_branch) { filter == :source_branches ? value : 'unmatched' }
        let(:author_username) { filter == :authors ? value : 'unmatched' }

        it { is_expected.to be(expected) }
      end
    end

    context 'with rules defined at multiple scopes (project > group > instance)' do
      let(:project_rules) { rules_yaml(target_branches: 'project-branch', authors: 'alice') }
      let(:ancestor_duo_template_projects) do
        [template_project(rules_yaml(target_branches: 'group-branch'), group: group)]
      end

      before do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:duo_template_project)
          .and_return(template_project(rules_yaml(target_branches: 'instance-branch')))
      end

      where(:target_branch, :author_username, :expected) do
        'instance-branch' | 'nobody' | false
        'group-branch'    | 'nobody' | false
        'project-branch'  | 'nobody' | true
        'unmatched'       | 'alice'  | true
      end

      with_them do
        it { is_expected.to be(expected) }
      end
    end

    context 'when the project overrides a group' do
      let(:project_rules) { rules_yaml(target_branches: 'project-branch') }
      let(:ancestor_duo_template_projects) do
        [template_project(rules_yaml(target_branches: 'group-branch'), group: group)]
      end

      where(:target_branch, :expected) do
        'project-branch' | true
        'group-branch'   | false
      end

      with_them do
        it { is_expected.to be(expected) }
      end
    end

    context 'when a group overrides the instance' do
      let(:ancestor_duo_template_projects) do
        [template_project(rules_yaml(target_branches: 'group-branch'), group: group)]
      end

      before do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:duo_template_project)
          .and_return(template_project(rules_yaml(target_branches: 'instance-branch')))
      end

      where(:target_branch, :expected) do
        'instance-branch' | false
        'group-branch'    | true
      end

      with_them do
        it { is_expected.to be(expected) }
      end
    end

    context 'when multiple ancestor groups define rules' do
      let(:ancestor_duo_template_projects) do
        [
          template_project(rules_yaml(target_branches: 'staging'), group: group),
          template_project(rules_yaml(target_branches: 'release', authors: 'renovate'), group: subgroup)
        ]
      end

      where(:target_branch, :author_username, :expected) do
        'staging'   | 'nobody'   | true
        'release'   | 'nobody'   | true
        'unmatched' | 'renovate' | true
        'unmatched' | 'nobody'   | false
      end

      with_them do
        it { is_expected.to be(expected) }
      end
    end

    context 'with instance-level rules' do
      let(:author_username) { 'renovate' }
      let(:instance_template) { template_project(rules_yaml(authors: 'renovate')) }

      before do
        allow(::Gitlab::CurrentSettings.current_application_settings)
          .to receive(:duo_template_project).and_return(instance_template)
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(is_saas)
      end

      context 'when self-managed' do
        let(:is_saas) { false }

        it { is_expected.to be(true) }

        context 'when the instance has no template project' do
          let(:instance_template) { nil }

          it { is_expected.to be(false) }
        end
      end

      context 'when on SaaS' do
        let(:is_saas) { true }

        it 'skips instance rules' do
          is_expected.to be(false)
        end
      end
    end

    context 'when the project has no group' do
      let(:project) { build_stubbed(:project, :with_code_review_automated_rules, automated_rules: project_rules) }
      let(:project_rules) { rules_yaml(authors: 'alice') }

      before do
        allow(resolver).to receive(:ancestor_duo_template_projects).and_call_original
      end

      it 'does not raise and still applies project rules' do
        expect(excluded).to be(true)
      end
    end

    context 'with malformed rules' do
      context 'when at the project level' do
        let(:project_rules) { 'invalid YAML format' }

        it { is_expected.to be(false) }

        it 'tracks the error against the project' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            ::Gitlab::Config::Loader::Yaml::NotHashError, project_id: project.id, type: :project, ref: 'main'
          ).once

          excluded
        end
      end

      context 'when at the group level' do
        let(:group_template) { template_project('invalid YAML format', group: group) }
        let(:ancestor_duo_template_projects) { [group_template] }

        it { is_expected.to be(false) }

        it 'tracks the error against the template project' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            ::Gitlab::Config::Loader::Yaml::NotHashError, project_id: group_template.id, type: :group, ref: 'main'
          ).once

          excluded
        end
      end
    end
  end
end
