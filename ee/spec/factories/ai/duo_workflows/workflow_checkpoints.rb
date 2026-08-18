# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_checkpoint, class: 'Ai::DuoWorkflows::Checkpoint' do
    workflow { association(:duo_workflows_workflow) }
    checkpoint { { key: 'value' } }
    trait :ui_chat_log do
      checkpoint do
        {
          key: 'value',
          channel_values: {
            ui_chat_log: [
              {
                status: "success",
                content: "hi",
                timestamp: "2025-11-25T21:10:57.734182+00:00",
                tool_info: nil,
                message_type: "user",
                correlation_id: nil,
                message_sub_type: nil,
                message_id: "user-#{SecureRandom.uuid}",
                additional_context: [{ 'id' => 'ctx-1', 'type' => 'file' }]
              }
            ]
          }
        }
      end
    end
    metadata { { metadata_key: 'metadata value' } }
    thread_ts { Gitlab::Utils.uuid_v7 }
    parent_ts { Gitlab::Utils.uuid_v7 }
    project { association(:project) }
  end
end
