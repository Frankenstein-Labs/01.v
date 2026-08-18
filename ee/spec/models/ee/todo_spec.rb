# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Todo, feature_category: :notifications do
  let_it_be(:current_user) { create(:user) }

  describe '#action_name' do
    let(:todo) { build(:todo) }

    where(:action_constant, :expected_action_name) do
      [
        [described_class::DUO_PRO_ACCESS_GRANTED, :duo_pro_access_granted],
        [described_class::ADDED_APPROVER, :added_approver],
        [described_class::OKR_CHECKIN_REQUESTED, :okr_checkin_requested],
        [described_class::MERGE_TRAIN_REMOVED, :merge_train_removed],
        [described_class::DUO_WORKFLOW_INPUT_REQUIRED, :duo_workflow_input_required]
      ]
    end

    with_them do
      it "maps #{params[:action_constant]} to :#{params[:expected_action_name]}" do
        todo.action = action_constant

        expect(todo.action_name).to eq(expected_action_name)
      end
    end
  end

  describe '#parentless_type?' do
    let(:todo) { build(:todo) }

    it 'returns true for a duo action type' do
      parentless_action = described_class::DUO_PRO_ACCESS_GRANTED
      todo.action = parentless_action

      expect(todo).to be_parentless_type
    end
  end

  describe '#body' do
    context 'for duo notification' do
      it 'returns enterprise duo message' do
        todo = build(:todo, :duo_enterprise_access, user: current_user)

        expect(todo.body).to include s_('Todos|You now have access to AI-native features')
      end
    end

    context 'for duo workflow input required notification' do
      it 'returns the workflow definition' do
        workflow = build(:duo_workflows_workflow, goal: 'Fix the critical pipeline failure',
          workflow_definition: 'fix_pipeline/v1')
        todo = build(:todo, :duo_workflow_input_required, target: workflow)

        expect(todo.body).to eq('fix_pipeline/v1')
      end
    end

    context 'for non duo notification' do
      it 'returns enterprise duo message' do
        issue = build(:issue)
        todo = build(:todo, target: issue)

        expect(todo.body).to eq(issue.title)
      end
    end
  end

  describe '#target_url' do
    subject { todo.target_url }

    context 'when the todo is coming from an epic' do
      let_it_be(:group) { create(:group, developers: current_user) }
      let_it_be_with_reload(:epic) { create(:epic, group: group) }

      context 'when coming from the epic itself' do
        let_it_be(:todo) { create(:todo, project: nil, group: group, user: current_user, target: epic) }

        it 'returns the work item web path' do
          is_expected.to eq("http://localhost/groups/#{group.full_path}/-/epics/#{epic.iid}")
        end
      end

      context 'when coming from a note on the epic' do
        let_it_be_with_reload(:note) { create(:note, noteable: epic) }
        let_it_be(:todo) do
          create(:todo, project: nil, group: group, user: current_user, note: note, target: epic)
        end

        it 'returns the work item web path with an anchor to the note' do
          is_expected.to eq("http://localhost/groups/#{group.full_path}/-/epics/#{epic.iid}#note_#{note.id}")
        end
      end
    end

    context 'when todo is for a Duo Workflow input required action' do
      let_it_be_with_reload(:project) { create(:project) }
      let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
      let_it_be(:todo) do
        create(:todo, :duo_workflow_input_required, project: project, user: current_user, target: workflow)
      end

      it { is_expected.to eq(workflow.web_url) }
    end

    context 'when todo is for any Duo access type being granted (Pro, Enterprise, or Core)' do
      let(:url) { ::Gitlab::Routing.url_helpers.help_page_path('user/get_started/getting_started_gitlab_duo.md') }

      where(:duo_type) { %i[duo_pro_access duo_enterprise_access duo_core_access] }

      with_them do
        let(:todo) { build(:todo, duo_type) }

        it { is_expected.to eq url }
      end
    end

    context 'when the todo is coming from a vulnerability' do
      let_it_be_with_reload(:project) { create(:project) }
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }

      context 'when coming from the vulnerability itself' do
        let_it_be(:todo) do
          create(:todo, project: project, group: project.group, user: current_user, target: vulnerability)
        end

        it 'returns the work item web path' do
          is_expected.to eq("http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}")
        end
      end

      context 'when coming from a note on the vulnerability' do
        let_it_be_with_reload(:note) { create(:note, noteable: vulnerability, project: project) }
        let_it_be(:todo) do
          create(:todo, project: project, group: project.group, user: current_user, note: note, target: vulnerability)
        end

        it 'returns the work item web path with an anchor to the note' do
          is_expected.to eq("http://localhost/#{project.full_path}/-/security/vulnerabilities/#{vulnerability.id}#note_#{note.id}")
        end
      end
    end

    context 'when the todo is coming from a compliance violation' do
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:project) { create(:project, namespace: group) }
      let_it_be_with_reload(:violation) { create(:project_compliance_violation, namespace: group, project: project) }

      context 'when coming from the epic itself' do
        let_it_be(:todo) do
          create(:todo, project: project, group: group, user: current_user, target: violation)
        end

        it 'returns the violation web path' do
          is_expected.to eq("http://localhost/#{project.full_path}/-/security/compliance_violations/#{violation.id}")
        end
      end

      context 'when coming from a note on the compliance violation' do
        let_it_be_with_reload(:note) { create(:note, noteable: violation, project: project) }
        let_it_be(:todo) do
          create(:todo, project: project, group: project.group, user: current_user, note: note, target: violation)
        end

        it 'returns the violations web path with an anchor to the note' do
          is_expected.to eq("http://localhost/#{project.full_path}/-/security/compliance_violations/#{violation.id}#note_#{note.id}")
        end
      end
    end
  end
end
