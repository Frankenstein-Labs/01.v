# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_checkpoint_write, class: 'Ai::DuoWorkflows::CheckpointWrite' do
    workflow { association(:duo_workflows_workflow) }
    thread_ts { Gitlab::Utils.uuid_v7 }
    project { association(:project) }
    task { 'id' }
    idx { 0 }
    channel { 'channel' }
    write_type { '__interrupt__' }
    data { 'some data' }
  end
end
