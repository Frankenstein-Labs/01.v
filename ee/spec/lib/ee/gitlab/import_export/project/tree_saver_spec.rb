# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::TreeSaver, feature_category: :importers do
  include TmpdirHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group, maintainers: user) }
  let_it_be(:issue) { create(:issue, project: project) }

  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:epic_issue) { create(:epic_issue, issue: issue, epic: epic) }

  let(:export_path) { mktmpdir }

  let_it_be(:push_rule) { create(:push_rule, project: project, max_file_size: 10) }
  let_it_be(:approval_rule) { create :approval_project_rule, project: project, approvals_required: 1 }
  let_it_be(:protected_branch) { create(:protected_branch, name: 'main', project: project) }
  let_it_be(:approval_rules_protected_branch) do
    joint_instance = create(
      :approval_project_rules_protected_branch,
      approval_project_rule: approval_rule,
      protected_branch: protected_branch
    )

    approval_rule.reload
    joint_instance
  end

  let_it_be(:approval_rules_user) do
    joint_instance = create(
      :approval_project_rules_user,
      approval_project_rule: approval_rule,
      user: user
    )

    approval_rule.reload
    joint_instance
  end

  shared_examples 'EE saves project tree successfully' do
    include ::ImportExport::CommonUtil

    let(:full_path) { File.join(shared.export_path, 'tree') }

    let(:shared) { project.import_export_shared }
    let(:project_tree_saver) { described_class.new(project: project, current_user: user, shared: shared) }
    let(:issue_json) { get_json(full_path, exportable_path, :issues).first }
    let(:exportable_path) { 'project' }
    let(:epics_available) { true }

    before do
      stub_all_feature_flags
      stub_licensed_features(epics: epics_available)
      allow(shared).to receive(:export_path).and_return(export_path)
    end

    context 'epics relation' do
      it 'contains issue epic object', :aggregate_failures do
        expect(project_tree_saver.save).to be true
        expect(issue_json['epic_issue']).not_to be_empty
        expect(issue_json['epic_issue']['id']).to eql(epic_issue.id)
        expect(issue_json['epic_issue']['epic']['title']).to eql(epic.title)
        expect(issue_json['epic_issue']['epic_id']).to be_nil
        expect(issue_json['epic_issue']['issue_id']).to be_nil
      end

      context 'when epic is not readable' do
        let(:epics_available) { false }

        it 'filters out inaccessible epic object' do
          expect(project_tree_saver.save).to be true
          expect(issue_json['epic_issue']).to be_nil
        end
      end

      context 'when restricted associations are present' do
        let_it_be(:notes) { create_list(:note, 3, :system, noteable: issue, project: project, author: user) }

        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?).with(user, :read_note, notes[1]).and_return(false)
        end

        it 'filters out only inaccessible resources', :aggregate_failures do
          expect(project_tree_saver.save).to be true
          expect(issue_json['epic_issue']).not_to be_empty
          expect(issue_json['epic_issue']['id']).to eql(epic_issue.id)
          expect(issue_json['notes']).not_to be_empty
          expect(issue_json['notes'].count).to eq(2)
          expect(issue_json['notes'].pluck('note')).to contain_exactly(notes[0].note, notes[2].note)
        end
      end
    end

    context 'push_rule' do
      let(:push_rule_json) do
        json = get_json(full_path, exportable_path, :push_rule)
        json.first
      end

      it 'has push rules' do
        expect(project_tree_saver.save).to be true
        expect(push_rule_json['max_file_size']).to eq(10)
      end
    end

    context 'approval_rules' do
      let(:approval_rules_json) do
        json = get_json(full_path, exportable_path, :approval_rules)
        json.is_a?(Array) ? json.first : json
      end

      it 'has approval rules' do
        expect(project_tree_saver.save).to be true
        expect(approval_rules_json['approvals_required']).to eq(1)
        expect(approval_rules_json['rule_type']).to eq('regular')
      end

      it 'has approval rules have protected branches' do
        expect(project_tree_saver.save).to be true
        expect(approval_rules_json['approval_project_rules_protected_branches'].count).to eq(1)

        joint_instance = approval_rules_json['approval_project_rules_protected_branches'].first
        expect(joint_instance['branch_name']).to eq(protected_branch.name)
      end

      it 'has approval rules have protected users' do
        expect(project_tree_saver.save).to be true
        expect(approval_rules_json['approval_project_rules_users'].count).to eq(1)

        joint_instance = approval_rules_json['approval_project_rules_users'].first
        expect(joint_instance['user_id']).to eq(user.id)
      end
    end

    context 'with squash options' do
      let!(:squash_option) do
        create(
          :branch_rule_squash_option,
          protected_branch: protected_branch,
          project: project,
          squash_option: 'always'
        )
      end

      let(:squash_option_json) { get_json(full_path, exportable_path, 'protected_branches').first['squash_option'] }

      it 'saves squash option' do
        expect(project_tree_saver.save).to be true

        expect(squash_option_json['squash_option']).to eq('always')
        expect(squash_option_json['project_id']).to eq(project.id)
      end
    end

    context 'with a custom work item type' do
      let_it_be(:custom_type) { create(:work_item_custom_type, :with_organization, organization: group.organization) }
      let_it_be(:custom_type_issue) do
        create(:issue, project: project, work_item_type_id: custom_type.id, title: 'custom type issue')
      end

      it 'exports work_item_type with the custom type name' do
        expect(project_tree_saver.save).to be true

        issues = get_json(full_path, exportable_path, :issues)
        exported_issue = issues.find { |i| i['title'] == 'custom type issue' }

        expect(exported_issue['work_item_type']).to eq('name' => custom_type.name)
      end
    end

    context 'vulnerabilities' do
      let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
      let!(:vulnerability) { create(:vulnerability, :detected, project: project, findings: [finding]) }

      let(:vulnerabilities) { get_json(full_path, exportable_path, :vulnerabilities) || [] }

      it 'exports and imports vulnerabilities' do
        project.project_setting.update!(has_vulnerabilities: true)

        expect(project_tree_saver.save).to be true

        expect(vulnerabilities).not_to be_empty
        json = vulnerabilities.detect { |v| v['title'] == vulnerability.title }
        expect(json).to include(
          'severity' => vulnerability.severity,
          'report_type' => vulnerability.report_type,
          'description' => vulnerability.description,
          'author_id' => vulnerability.author_id
        )
        expect(vulnerabilities.size).to eq(project.vulnerabilities.count)
      end
    end
  end

  it_behaves_like 'EE saves project tree successfully'
end
