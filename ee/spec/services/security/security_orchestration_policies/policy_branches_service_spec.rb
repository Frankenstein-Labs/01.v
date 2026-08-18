# frozen_string_literal: true

require "spec_helper"

RSpec.describe Security::SecurityOrchestrationPolicies::PolicyBranchesService, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:project) { create(:project, :empty_repo) }
  let_it_be(:default_branch) { "master" }
  let_it_be(:protected_branch) { "protected" }
  let_it_be(:unprotected_branch) { "feature" }
  let(:rules) { [rule] }

  before_all do
    sha = project.repository.create_file(
      project.creator,
      "README.md",
      "",
      message: "initial commit",
      branch_name: default_branch)

    [default_branch, protected_branch, unprotected_branch].each do |branch|
      project.repository.add_branch(project.creator, branch, sha)
    end

    [default_branch, protected_branch].each do |branch|
      project.protected_branches.create!(name: branch)
    end

    project.repository.raw_repository.write_ref("HEAD", "refs/heads/#{default_branch}")
  end

  %i[scan_execution_branches scan_result_branches].each do |method|
    describe method do
      subject(:execute) do
        Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project).public_send(method, rules)
      end

      describe "branches" do
        # rubocop: disable Performance/CollectionLiteralInLoop, Layout/LineLength
        where(:branches, :branch_type, :branch_exceptions, :result) do
          # branches
          ([]            | nil | nil | [])                   if method == :scan_execution_branches
          ([]            | nil | nil | %w[master protected]) if method == :scan_result_branches
          %w[foobar]     | nil | nil | []
          %w[master]     | nil | nil | %w[master]
          %w[mas* pro*]  | nil | nil | %w[master protected]

          # branch_type
          (nil | "all"        | nil | %w[master protected feature]) if method == :scan_execution_branches
          (nil | "all"        | nil | %w[master protected])         if method == :scan_result_branches
          nil  | "protected"  | nil | %w[master protected]
          nil  | "default"    | nil | %w[master]
          nil  | "invalid"    | nil | []

          # branch_exceptions
          %w[mas* pro*]    | nil     | %w[master]                                                  | %w[protected]
          %w[mas* pro*]    | nil     | %w[pro*]                                                    | %w[master]
          %w[mas* pro*]    | nil     | [{ name: "master", full_path: lazy { project.full_path } }] | %w[protected]
          %w[mas* pro*]    | nil     | [{ name: "master", full_path: "other" }]                    | %w[master protected]
          nil              | "all"   | %w[*]                                                       | []

          # invalid branch_exceptions
          nil | "protected" | [{}] | %w[master protected]
          nil | "protected" | [{ name: "master" }] | %w[master protected]
          nil | "protected" | [{ full_path: lazy { project.full_path } }] | %w[master protected]
        end
        # rubocop: enable Performance/CollectionLiteralInLoop, Layout/LineLength

        with_them do
          let(:rule) { { branch_type: branch_type, branches: branches, branch_exceptions: branch_exceptions }.compact }

          specify do
            expect(execute).to eq(result.to_set)
          end
        end
      end

      context "with agent" do
        let(:rule) { { agents: { production: {} } } }

        specify do
          expect(execute).to be_empty
        end
      end

      if method == :scan_result_branches
        context "with unprotected default branch" do
          let(:rule) { { branch_type: "default" } }

          before do
            project.protected_branches.find_by!(name: default_branch).delete
          end

          specify do
            expect(execute).to be_empty
          end
        end
      end

      context "with multiple rules" do
        let(:rules) do
          [
            { branch_type: "default" },
            { branch_type: "protected" },
            { branches: [unprotected_branch] }
          ]
        end

        let(:expected_branches) do
          case method
          when :scan_execution_branches then [default_branch, protected_branch, unprotected_branch]
          when :scan_result_branches then [default_branch, protected_branch]
          end
        end

        specify do
          expect(execute).to contain_exactly(*expected_branches)
        end
      end

      context "with group-level protected branches" do
        let_it_be_with_reload(:group) { create(:group) }
        let(:rule) { { branch_type: "protected" } }
        let(:branch_name) { "develop" }
        let(:method) { :scan_execution_branches }

        before do
          project.group = group
          project.save!

          group.protected_branches.create!(name: branch_name)
        end

        after do
          project.repository.delete_branch(branch_name)
        end

        context 'when branch is not present in project' do
          specify do
            expect(execute).to include(branch_name)
          end
        end

        context 'when branch is present in project' do
          before do
            project.repository.add_branch(project.creator, branch_name, project.repository.head_commit.sha)
          end

          specify do
            expect(execute).to include(branch_name)
          end
        end
      end

      context "with empty repository" do
        let_it_be(:project) { create(:project, :empty_repo) }

        let(:rule) { { branch_type: "all" } }

        specify do
          expect(execute).to be_empty
        end
      end
    end
  end

  describe '#scan_execution_branches' do
    let(:service) { described_class.new(project: project) }
    let(:source_branch) { nil }

    subject(:scan_execution_branches) { service.scan_execution_branches(rules, source_branch) }

    context 'when target_default rule is provided in rules' do
      let(:rules) { [{ branch_type: 'target_default' }] }

      context 'when source_branch is nil' do
        let(:source_branch) { nil }

        it { is_expected.to be_empty }
      end

      context 'when source_branch is provided' do
        let(:source_branch) { unprotected_branch }

        context 'with open merge request created from that branch targetting default branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: default_branch)
          end

          it { is_expected.to match_array([source_branch]) }
        end

        context 'with open merge request created from that branch targetting default branch in different project' do
          let_it_be(:other_project) { create(:project, :empty_repo) }

          before do
            create(:merge_request, :opened, source_project: other_project, source_branch: source_branch,
              target_project: other_project, target_branch: default_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'with open merge request created from that branch targetting other protected branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: protected_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'with closed merge request created from that branch' do
          before do
            create(:merge_request, :closed, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: default_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'with no merge request created from that branch' do
          it { is_expected.to be_empty }
        end
      end
    end

    context 'when target_protected rule is provided in rules' do
      let(:rules) { [{ branch_type: 'target_protected' }] }

      context 'when source_branch is nil' do
        let(:source_branch) { nil }

        it { is_expected.to be_empty }
      end

      context 'when source_branch is provided' do
        let(:source_branch) { unprotected_branch }

        context 'with open merge request created from that branch targetting default branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: default_branch)
          end

          it { is_expected.to match_array([source_branch]) }
        end

        context 'with open merge request created from that branch targetting other protected branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: protected_branch)
          end

          it { is_expected.to match_array([source_branch]) }
        end

        context 'with 2 open merge requests created from that branch targetting different protected branches' do
          let_it_be(:protected_branch_2) { "protected-2" }

          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: protected_branch)

            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: protected_branch_2)
          end

          it { is_expected.to match_array([source_branch]) }
        end

        context 'with open merge request created from that branch targetting same branch in other project' do
          let_it_be(:other_project) { create(:project, :empty_repo) }

          before do
            create(:merge_request, :opened, source_project: other_project, source_branch: source_branch,
              target_project: other_project, target_branch: protected_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'with closed merge request created from that branch' do
          before do
            create(:merge_request, :closed, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: default_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'when there is no merge request created from that branch' do
          it { is_expected.to be_empty }
        end
      end
    end

    context 'when target_protected rule with branch_exceptions is provided in rules' do
      let(:source_branch) { unprotected_branch }

      context 'when branch_exceptions is a string matching the target branch' do
        let(:rules) { [{ branch_type: 'target_protected', branch_exceptions: [protected_branch] }] }

        context 'with open MR targeting the excepted branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: protected_branch)
          end

          it { is_expected.to be_empty }
        end

        context 'with no open MR' do
          it { is_expected.to be_empty }
        end
      end

      context 'when branch_exceptions is a wildcard matching the target branch' do
        let(:rules) { [{ branch_type: 'target_protected', branch_exceptions: ['pro*'] }] }

        before do
          create(:merge_request, :opened, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: protected_branch)
        end

        it { is_expected.to be_empty }
      end

      context 'when branch_exceptions is a hash scoped to this project' do
        let(:rules) do
          [{ branch_type: 'target_protected',
             branch_exceptions: [{ name: protected_branch, full_path: project.full_path }] }]
        end

        before do
          create(:merge_request, :opened, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: protected_branch)
        end

        it { is_expected.to be_empty }
      end

      context 'when branch_exceptions is a hash scoped to a different project' do
        let(:rules) do
          [{ branch_type: 'target_protected',
             branch_exceptions: [{ name: protected_branch, full_path: 'other/project' }] }]
        end

        before do
          create(:merge_request, :opened, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: protected_branch)
        end

        it { is_expected.to match_array([source_branch]) }
      end

      context 'with open MR targeting a non-excepted protected branch' do
        let(:rules) { [{ branch_type: 'target_protected', branch_exceptions: [protected_branch] }] }
        let(:other_protected_branch) { "other-protected" }

        before do
          project.repository.add_branch(project.creator, other_protected_branch,
            project.repository.head_commit.sha)
          project.protected_branches.create!(name: other_protected_branch)

          create(:merge_request, :opened, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: other_protected_branch)
        end

        after do
          project.repository.delete_branch(other_protected_branch)
          project.protected_branches.find_by(name: other_protected_branch)&.delete
        end

        it { is_expected.to match_array([source_branch]) }
      end
    end

    context 'when target_default rule with branch_exceptions is provided in rules' do
      let(:source_branch) { unprotected_branch }

      context 'when branch_exceptions contains the default branch' do
        let(:rules) { [{ branch_type: 'target_default', branch_exceptions: [default_branch] }] }

        context 'with open MR from source_branch targeting the excepted default branch' do
          before do
            create(:merge_request, :opened, source_project: project, source_branch: source_branch,
              target_project: project, target_branch: default_branch)
          end

          it { is_expected.to be_empty }
        end
      end
    end

    context 'when multiple rules include target_protected with branch_exceptions and a broad branches rule' do
      let(:source_branch) { unprotected_branch }
      let(:rules) do
        [
          { branch_type: 'target_protected', branch_exceptions: [protected_branch] },
          { branches: ['*'] }
        ]
      end

      context 'with open MR from source_branch targeting the excepted protected branch' do
        before do
          create(:merge_request, :opened, source_project: project, source_branch: source_branch,
            target_project: project, target_branch: protected_branch)
        end

        it 'still includes source_branch because the branches rule matches it independently' do
          expect(scan_execution_branches).to include(source_branch)
        end
      end
    end

    where(:branch_type, :tracked_branch_type) do
      'target_default'   | 'target_default'
      'target_protected' | 'target_protected'
      'default'          | 'default'
      'protected'        | 'protected'
      'all'              | 'all'
      nil                | 'custom'
      ''                 | 'custom'
    end

    with_them do
      let(:rules) { [{ branch_type: branch_type }] }

      it "triggers trigger_scan_execution_policy_by_branch_type event" do
        expect { scan_execution_branches }
          .to trigger_internal_events('trigger_scan_execution_policy_by_branch_type')
          .with(
            namespace: project.namespace,
            project: project,
            additional_properties: {
              label: tracked_branch_type
            }
          )
      end
    end
  end

  describe '#skip_validation?' do
    let(:service) { described_class.new(project: project) }

    where(:branch_type, :expected_result) do
      'target_default'   | true
      'target_protected' | true
      'default'          | false
      'protected'        | false
      'all'              | false
      nil                | false
      ''                 | false
    end

    with_them do
      let(:rule) { { branch_type: branch_type } }

      subject(:result) { service.skip_validation?(rule) }

      it 'returns the expected result' do
        expect(result).to eq(expected_result)
      end
    end

    context 'when branch_type is not present in the rule' do
      let(:rule) { { other_key: 'value' } }

      it 'returns false' do
        expect(service.skip_validation?(rule)).to be false
      end
    end
  end
end
