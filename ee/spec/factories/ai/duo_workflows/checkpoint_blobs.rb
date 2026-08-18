# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_checkpoint_blob, class: 'Ai::DuoWorkflows::CheckpointBlob' do
    workflow { association(:duo_workflows_workflow) }
    thread_ts { Gitlab::Utils.uuid_v7 }
    current_thread { 0 }
    channel { 'messages' }
    version { '1' }
    write_type { 'msgpack' }
    step_action { 'conversation' }
    data { 'blob-data' }
    project { workflow.project }
    # Mirror the write path: the partition key is the workflow's created_at.
    workflow_created_at { workflow.created_at }
  end
end
