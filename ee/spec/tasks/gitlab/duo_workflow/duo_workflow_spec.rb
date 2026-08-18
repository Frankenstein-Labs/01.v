# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo_workflow rake tasks', :silence_stdout, feature_category: :duo_agent_platform do
  before do
    Rake.application.rake_require 'tasks/gitlab/duo_workflow/duo_workflow'
  end

  describe 'gitlab:duo_workflow:populate' do
    let!(:user) { create(:user) }
    let!(:project) { create(:project) }
    let!(:gitlab_test_project) do
      create(:project, path: 'test', namespace: create(:group, path: 'gitlab-duo'))
    end

    it 'creates the specified number of workflows' do
      expect { run_rake_task('gitlab:duo_workflow:populate', '5', '2') }
        .to change { Ai::DuoWorkflows::Workflow.count }.by(5)
    end

    it 'assigns the specified number of workflows to first available user when no user specified' do
      run_rake_task('gitlab:duo_workflow:populate', '10', '3')

      expect(Ai::DuoWorkflows::Workflow.count).to eq(10)
      first_user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: User.first.id)
      expect(first_user_workflows.count).to eq(3)
    end

    it 'assigns workflows to specified user by ID' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.id.to_s)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to specified user by email' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.email)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to specified user by username' do
      run_rake_task('gitlab:duo_workflow:populate', '5', '2', user.username)

      expect(Ai::DuoWorkflows::Workflow.count).to eq(5)
      user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: user.id)
      expect(user_workflows.count).to eq(2)
    end

    it 'assigns workflows to default project when no project specified' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1')

      workflows = Ai::DuoWorkflows::Workflow.all
      expect(workflows.count).to eq(3)
      expect(workflows.pluck(:project_id)).to eq([gitlab_test_project.id] * 3)
    end

    it 'assigns workflows to specified project by path' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1', '', project.full_path)

      workflows = Ai::DuoWorkflows::Workflow.all
      expect(workflows.count).to eq(3)
      expect(workflows.pluck(:project_id)).to eq([project.id] * 3)
    end

    it 'creates workflows with valid attributes' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1')

      workflow = Ai::DuoWorkflows::Workflow.last
      expect(workflow).to have_attributes(
        goal: be_present,
        status: be_present,
        workflow_definition: be_in(%w[software_development chat convert_to_gitlab_ci]),
        agent_privileges: be_present,
        pre_approved_agent_privileges: be_present,
        user: be_present,
        project: be_present
      )
    end

    it 'creates checkpoints for each workflow' do
      expect { run_rake_task('gitlab:duo_workflow:populate', '5', '2') }
        .to change { Ai::DuoWorkflows::Checkpoint.count }.by_at_least(5)
    end

    it 'creates pipelines and workloads for each workflow' do
      expect { run_rake_task('gitlab:duo_workflow:populate', '3', '1') }
        .to change { Ci::Pipeline.count }.by(3)
        .and change { Ci::Workloads::Workload.count }.by(3)
        .and change { Ai::DuoWorkflows::WorkflowsWorkload.count }.by(3)
    end

    it 'creates pipelines with valid attributes' do
      run_rake_task('gitlab:duo_workflow:populate', '2', '1')

      pipeline = Ci::Pipeline.last
      expect(pipeline).to have_attributes(
        project: be_present,
        user: be_present,
        ref: be_present,
        sha: be_present,
        status: 'success',
        source: 'web'
      )
    end

    it 'creates workloads linked to workflows' do
      run_rake_task('gitlab:duo_workflow:populate', '2', '1')

      workflow = Ai::DuoWorkflows::Workflow.last
      workflows_workload = Ai::DuoWorkflows::WorkflowsWorkload.find_by(workflow: workflow)

      expect(workflows_workload).to be_present
      expect(workflows_workload.workload).to be_present
      expect(workflows_workload.project).to eq(workflow.project)
    end

    it 'creates checkpoints with valid attributes' do
      run_rake_task('gitlab:duo_workflow:populate', '3', '1')

      checkpoint = Ai::DuoWorkflows::Checkpoint.last
      expect(checkpoint).to have_attributes(
        workflow: be_present,
        project: be_present,
        thread_ts: be_present,
        checkpoint: be_present,
        metadata: be_present
      )

      # Verify checkpoint JSONB structure
      expect(checkpoint.checkpoint).to include(
        'v' => be_present,
        'id' => be_present,
        'ts' => be_present,
        'channel_values' => include(
          'status' => be_present,
          'ui_chat_log' => be_present
        )
      )

      # Verify metadata JSONB structure
      expect(checkpoint.metadata).to include(
        'step' => be_present,
        'source' => be_present,
        'thread_id' => be_present
      )
    end

    context 'when checkpoint creation based on workflow status' do
      it 'creates checkpoints with correct status progression for different workflow states' do
        run_rake_task('gitlab:duo_workflow:populate', '10', '5')

        workflows = Ai::DuoWorkflows::Workflow.all
        workflows.each do |workflow|
          checkpoints = workflow.checkpoints.order(:thread_ts)

          case workflow.status
          when 0, 1 # created, running
            expect(checkpoints.count).to eq(1)
            expect(checkpoints.first.checkpoint).to include(
              'channel_values' => include('status' => 'STARTED')
            )
          when 2, 3, 4 # paused, finished, failed
            expect(checkpoints.count).to eq(2)
            expect(checkpoints.first.checkpoint).to include(
              'channel_values' => include('status' => 'STARTED')
            )
            expect(checkpoints.second.checkpoint).to include(
              'channel_values' => include('status' => 'IN_PROGRESS')
            )
          when 5, 6, 7, 8 # stopped, input_required, plan_approval_required, tool_call_approval_required
            expect(checkpoints.count).to eq(3)
            expect(checkpoints.first.checkpoint).to include(
              'channel_values' => include('status' => 'STARTED')
            )
            expect(checkpoints.second.checkpoint).to include(
              'channel_values' => include('status' => 'IN_PROGRESS')
            )
            expect(checkpoints.third.checkpoint).to include(
              'channel_values' => include('status' => 'FINISHED')
            )
          end
        end
      end

      it 'creates checkpoints with valid UI chat log entries' do
        run_rake_task('gitlab:duo_workflow:populate', '2', '1')

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        ui_chat_log = checkpoint.checkpoint['channel_values']['ui_chat_log']

        expect(ui_chat_log).to be_an(Array)
        expect(ui_chat_log.length).to eq(8)

        # Verify specific message types
        expect(ui_chat_log[0]['message_type']).to eq('tool')
        expect(ui_chat_log[1]['message_type']).to eq('tool')
        expect(ui_chat_log[2]['message_type']).to eq('tool')
        expect(ui_chat_log[3]['message_type']).to eq('request')
        expect(ui_chat_log[4]['message_type']).to eq('user')
        expect(ui_chat_log[5]['message_type']).to eq('agent')
        expect(ui_chat_log[6]['message_type']).to eq('user')
        expect(ui_chat_log[7]['message_type']).to eq('workflow_end')

        # Verify tool_info structure for tool messages
        tool_message_with_args = ui_chat_log[1]
        expect(tool_message_with_args['tool_info']).to include(
          'name' => 'read_file',
          'args' => include('file_path' => be_present)
        )

        tool_message_without_args = ui_chat_log[2]
        expect(tool_message_without_args['tool_info']).to include(
          'name' => 'get_issue'
        )

        # Verify non-tool messages have nil tool_info
        expect(ui_chat_log[0]['tool_info']).to be_nil
        expect(ui_chat_log[3]['tool_info']).to be_nil
        expect(ui_chat_log[4]['tool_info']).to be_nil
        expect(ui_chat_log[5]['tool_info']).to be_nil
        expect(ui_chat_log[6]['tool_info']).to be_nil
        expect(ui_chat_log[7]['tool_info']).to be_nil
      end

      it 'creates checkpoints with workflow goal referenced in chat log' do
        run_rake_task('gitlab:duo_workflow:populate', '1', '1')

        workflow = Ai::DuoWorkflows::Workflow.last
        checkpoint = workflow.checkpoints.first
        ui_chat_log = checkpoint.checkpoint['channel_values']['ui_chat_log']

        first_message = ui_chat_log.first['content']
        expect(first_message).to include('Starting workflow with goal:')
        expect(first_message).to include(workflow.goal.split(' (Workflow #').first)
      end

      it 'creates checkpoints with properly structured tool_info data' do
        run_rake_task('gitlab:duo_workflow:populate', '1', '1')

        checkpoint = Ai::DuoWorkflows::Checkpoint.last
        ui_chat_log = checkpoint.checkpoint['channel_values']['ui_chat_log']

        # Find the read_file tool message
        read_file_message = ui_chat_log.find { |msg| msg['tool_info']&.dig('name') == 'read_file' }
        expect(read_file_message).to be_present
        expect(read_file_message['tool_info']).to include(
          'name' => 'read_file',
          'args' => include(
            'file_path' => 'app/assets/very-long-path/that-wont-end/ohnopleasehelpmeIamgoingoffscreenaaaaaaaaaa'
          )
        )

        # Find the get_issue tool message
        get_issue_message = ui_chat_log.find { |msg| msg['tool_info']&.dig('name') == 'get_issue' }
        expect(get_issue_message).to be_present
        expect(get_issue_message['tool_info']).to include(
          'name' => 'get_issue'
        )
        expect(get_issue_message['tool_info']).not_to have_key('args')

        # Verify message content matches expected pattern
        expect(read_file_message['content']).to eq('Read file')
        expect(get_issue_message['content']).to eq('Read issue http://gdk.test:3000/gitlab-duo/test/-/issues/1')
      end
    end

    it 'uses default values when no arguments provided' do
      expect { run_rake_task('gitlab:duo_workflow:populate') }
        .to change { Ai::DuoWorkflows::Workflow.count }.by(50)
        .and change { Ai::DuoWorkflows::Checkpoint.count }.by_at_least(50)
        .and change { Ci::Pipeline.count }.by(50)
        .and change { Ci::Workloads::Workload.count }.by(50)

      first_user_workflows = Ai::DuoWorkflows::Workflow.where(user_id: User.first.id)
      expect(first_user_workflows.count).to eq(24)
    end

    context 'when current_user_count exceeds total count' do
      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '5', '10') }
          .to raise_error(SystemExit)
      end
    end

    context 'when specified user does not exist' do
      it 'exits with error for invalid user ID' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', '99999') }
          .to raise_error(SystemExit)
      end

      it 'exits with error for invalid email' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', 'nonexistent@example.com') }
          .to raise_error(SystemExit)
      end

      it 'exits with error for invalid username' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', 'nonexistent_user') }
          .to raise_error(SystemExit)
      end
    end

    context 'when specified project does not exist' do
      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1', '', 'nonexistent/project') }
          .to raise_error(SystemExit)
      end
    end

    context 'when default project does not exist' do
      before do
        gitlab_test_project.destroy!
      end

      it 'falls back to first available project' do
        run_rake_task('gitlab:duo_workflow:populate', '3', '1')

        workflows = Ai::DuoWorkflows::Workflow.all
        expect(workflows.count).to eq(3)
        expect(workflows.pluck(:project_id)).to eq([Project.first.id] * 3)
      end
    end

    context 'when no projects exist' do
      before do
        Project.delete_all
      end

      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1') }
          .to raise_error(SystemExit)
      end
    end

    context 'when no users exist' do
      before do
        User.delete_all
      end

      it 'exits with error' do
        expect { run_rake_task('gitlab:duo_workflow:populate', '1', '1') }
          .to raise_error(SystemExit)
      end
    end
  end
end
