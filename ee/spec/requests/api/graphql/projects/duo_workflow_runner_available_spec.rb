# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'querying duoWorkflowRunnerAvailable', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :with_duo_features_enabled) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  let(:workload_tag) { ::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG }

  def query_field(user: current_user)
    result = GitlabSchema.execute(%(
      query {
        project(fullPath: "#{project.full_path}") {
          duoWorkflowRunnerAvailable
        }
      }
    ), context: { current_user: user }).as_json

    result.dig('data', 'project', 'duoWorkflowRunnerAvailable')
  end

  before do
    # Stub the entitlement seams so the real :duo_workflow policy grant is exercised.
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
    allow(::Ai::DuoWorkflow).to receive(:duo_agent_platform_available?).with(project).and_return(true)
    allow(current_user).to receive(:allowed_to_use?).and_return(true)
  end

  it 'is false when the project has no runner that could pick up the workload' do
    expect(query_field).to be(false)
  end

  it 'is true once a usable runner exists' do
    runner = create(:ci_runner, :instance, :online, tag_list: [workload_tag])
    create(:ci_runner_machine, runner: runner, executor_type: :docker)

    expect(query_field).to be(true)
  end

  describe 'duoWorkflowUsableRunnerType' do
    def query_both(user: current_user)
      result = GitlabSchema.execute(%(
        query {
          project(fullPath: "#{project.full_path}") {
            duoWorkflowRunnerAvailable
            duoWorkflowUsableRunnerType
          }
        }
      ), context: { current_user: user }).as_json

      result.dig('data', 'project')
    end

    it 'is the type of the runner that satisfied the check' do
      runner = create(:ci_runner, :instance, :online, tag_list: [workload_tag])
      create(:ci_runner_machine, runner: runner, executor_type: :docker)

      expect(query_both).to eq(
        'duoWorkflowRunnerAvailable' => true,
        'duoWorkflowUsableRunnerType' => 'instance_type'
      )
    end

    it 'is nil when no runner qualifies' do
      expect(query_both['duoWorkflowUsableRunnerType']).to be_nil
    end

    it 'runs the runner scan once when both fields are requested' do
      expect(::Ai::DuoWorkflow::ProjectReadiness).to receive(:new).once.and_call_original

      query_both
    end
  end

  # Runner topology is not public information.
  it 'is nil for a user who cannot use Duo Agent Platform here' do
    outsider = create(:user, guest_of: project)

    expect(query_field(user: outsider)).to be_nil
  end

  it 'is not resolved unless it is requested' do
    expect(::Ai::DuoWorkflow::ProjectReadiness).not_to receive(:new)

    GitlabSchema.execute(%(
      query { project(fullPath: "#{project.full_path}") { id } }
    ), context: { current_user: current_user })
  end
end
