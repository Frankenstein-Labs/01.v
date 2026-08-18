# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::RelationFactory, feature_category: :importers do
  let(:user) { create(:user, admin: true) }
  let_it_be(:project, freeze: false) { create(:project) }

  let(:group) { create(:group) }
  let(:created_object) do
    described_class.create( # rubocop:disable Rails/SaveBang
      relation_sym: relation_sym,
      relation_hash: relation_hash,
      relation_index: 1,
      members_mapper: instance_double('Gitlab::ImportExport::MembersMapper', map: {}),
      object_builder: Gitlab::ImportExport::Project::ObjectBuilder,
      user: user,
      importable: project,
      import_source: :gitlab_project,
      excluded_keys: []
    )
  end

  describe 'iteration' do
    let(:relation_sym) { :iteration }
    let(:relation_hash) do
      {
        'iid' => 1,
        'start_date' => '2022-01-01',
        'due_date' => '2022-02-02',
        'description' => 'iteration',
        'iterations_cadence' => {
          'title' => 'iterations cadence'
        }
      }
    end

    context 'when project has no group' do
      it 'does not create iteration' do
        expect(created_object).to be_nil
      end
    end
  end

  describe 'resource iteration events' do
    let(:relation_sym) { :resource_iteration_events }
    let(:relation_hash) do
      {
        'user_id' => 1,
        'created_at' => '2022-08-17T13:04:02.495Z',
        'action' => 'add',
        'iteration' => nil
      }
    end

    context 'when iteration object has no iteration associated' do
      let(:project) { create(:project, group: group) }

      it 'does not create resource iteration event' do
        expect(created_object).to be_nil
      end
    end

    context 'when project has no group' do
      it 'does not create resource iteration event' do
        expect(created_object).to be_nil
      end
    end
  end

  describe 'push_rule' do
    let(:relation_sym) { :push_rule }
    let(:relation_hash) do
      {
        'commit_message_regex' => 'JIRA\-\d+',
        'branch_name_regex' => nil,
        'deny_delete_tag' => false,
        'member_check' => false,
        'prevent_secrets' => false
      }
    end

    context 'when project has no push rule' do
      it 'creates push rule' do
        expect(created_object).to be_a(PushRule)
      end
    end

    context 'when project already has a push rule' do
      before do
        create(:push_rule, project: project)
      end

      it 'returns the existing push rule' do
        expect(created_object).to be_a(PushRule)
        expect(created_object).to eq(project.push_rule)
      end
    end
  end

  context 'when parsing approval_rules_protected_branches object' do
    let_it_be(:first_protected_branch) { create :protected_branch, project: project }
    let_it_be(:protected_branch) { create :protected_branch, name: 'main', project: project }
    let_it_be(:branch_name) { protected_branch.name }
    let_it_be(:relation_sym) { :approval_project_rules_protected_branches }
    let(:approval_rule) { create :approval_project_rule, project: project }
    let(:relation_hash) do
      {
        "approval_project_rule_id" => approval_rule.id,
        "protected_branch_id" => 888,
        "branch_name" => branch_name
      }
    end

    it 'belongs to the new protected branch' do
      expect(created_object.protected_branch_id).to eq(protected_branch.id)
    end

    context 'when branch name is not found' do
      let(:relation_hash) do
        {
          "approval_project_rule_id" => approval_rule.id,
          "protected_branch_id" => 888,
          "branch_name" => 'fake_master'
        }
      end

      it 'protected_branch_id is nil' do
        expect(created_object.protected_branch_id).to be_nil
      end
    end
  end

  context 'when parsing an issue', :request_store, :clean_gitlab_redis_shared_state do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:project_in_group) { create(:project, group: root_group) }

    let(:project) { project_in_group }
    let(:relation_sym) { :issues }
    let(:incident_type) { build(:work_item_system_defined_type, :incident) }
    let(:relation_hash) do
      {
        'iid' => 1,
        'title' => 'an issue',
        'author_id' => user.id,
        'project_id' => project.id,
        'state' => 'opened',
        'work_item_type' => { 'name' => incident_type.name }
      }
    end

    context 'when the matched type is disabled in the target namespace' do
      before do
        create(:work_item_settings,
          namespace: nil, organization: root_group.organization, customizable_type_visibility: true)
        create(:work_item_type_visibility,
          namespace: root_group, work_item_type_id: incident_type.id, enabled: false, propagate: true)
      end

      it 'falls back to the default issue type' do
        issue_type = build(:work_item_system_defined_type, :issue)

        expect(created_object.work_item_type_id).to eq(issue_type.id)
      end

      it 'attaches the missing work item type label to the issue' do
        expect(created_object.label_links.map(&:label_id))
          .to contain_exactly(label_id_for(incident_type.name))
      end
    end

    context 'when the matched type is enabled in the target namespace' do
      it 'sets the matched type' do
        expect(created_object.work_item_type_id).to eq(incident_type.id)
      end

      it 'does not attach the missing work item type label' do
        expect(created_object.label_links).to be_empty
      end
    end

    context 'when the matched type is not visible in the target context (epic on project)' do
      let(:epic_type) { build(:work_item_system_defined_type, :epic) }
      let(:relation_hash) do
        {
          'iid' => 1,
          'title' => 'an epic',
          'author_id' => user.id,
          'project_id' => project.id,
          'state' => 'opened',
          'work_item_type' => { 'name' => epic_type.name }
        }
      end

      before do
        stub_licensed_features(epics: true)
      end

      it 'falls back to the default issue type' do
        issue_type = build(:work_item_system_defined_type, :issue)

        expect(created_object.work_item_type_id).to eq(issue_type.id)
      end

      it 'attaches the missing work item type label to the issue' do
        expect(created_object.label_links.map(&:label_id))
          .to contain_exactly(label_id_for(epic_type.name))
      end
    end

    context 'when the name does not match any existing type' do
      let(:relation_hash) do
        {
          'iid' => 1,
          'title' => 'an issue with unknown type',
          'author_id' => user.id,
          'project_id' => project.id,
          'state' => 'opened',
          'work_item_type' => { 'name' => 'Non-existent type' }
        }
      end

      it 'falls back to the default issue type' do
        issue_type = build(:work_item_system_defined_type, :issue)

        expect(created_object.work_item_type_id).to eq(issue_type.id)
      end

      it 'attaches the missing work item type label to the issue' do
        expect(created_object.label_links.map(&:label_id))
          .to contain_exactly(label_id_for('Non-existent type'))
      end
    end

    context 'when using legacy base_type format' do
      let(:relation_hash) do
        {
          'iid' => 1,
          'title' => 'a legacy issue',
          'author_id' => user.id,
          'project_id' => project.id,
          'state' => 'opened',
          'work_item_type' => { 'base_type' => 'incident' }
        }
      end

      it 'does not attach the missing work item type label' do
        expect(created_object.label_links).to be_empty
      end
    end

    context 'when multiple issues share the same missing type name' do
      let(:other_relation_hash) do
        relation_hash.merge('iid' => 2, 'title' => 'another issue')
      end

      let(:other_object) do
        described_class.create( # rubocop:disable Rails/SaveBang
          relation_sym: relation_sym,
          relation_hash: other_relation_hash,
          relation_index: 2,
          members_mapper: instance_double(Gitlab::ImportExport::MembersMapper, map: {}),
          object_builder: Gitlab::ImportExport::Project::ObjectBuilder,
          user: user,
          importable: project,
          import_source: :gitlab_project,
          excluded_keys: []
        )
      end

      let(:relation_hash) do
        {
          'iid' => 1,
          'title' => 'an issue',
          'author_id' => user.id,
          'project_id' => project.id,
          'state' => 'opened',
          'work_item_type' => { 'name' => 'Yet another missing type' }
        }
      end

      it 'reuses the same label for both issues' do
        expected_label_id = label_id_for('Yet another missing type')

        expect(created_object.label_links.map(&:label_id)).to contain_exactly(expected_label_id)
        expect(other_object.label_links.map(&:label_id)).to contain_exactly(expected_label_id)
        expect(project.labels.where(title: "#{_('imported')}:Yet another missing type").count).to eq(1)
      end
    end

    def label_id_for(type_name)
      Gitlab::ImportExport::Project::MissingWorkItemTypeLabel.new(project).id_for(type_name)
    end
  end
end
