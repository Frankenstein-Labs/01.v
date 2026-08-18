# frozen_string_literal: true

RSpec.shared_examples 'creates CI pipeline for Duo Workflow execution' do
  it 'creates CI pipeline to execute the workflow' do
    expect_next_instance_of(Ci::CreatePipelineService) do |pipeline_service|
      expect(pipeline_service).to receive(:execute).and_call_original
    end

    subject

    expect(::Ci::Pipeline.last.project_id).to eq(project.id)
  end
end

RSpec.shared_examples 'prevents CI pipeline creation for Duo Workflow' do
  it 'does not create a CI pipeline for workflow execution' do
    expect(Ci::CreatePipelineService).not_to receive(:new)

    subject
  end
end
