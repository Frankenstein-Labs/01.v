# frozen_string_literal: true

FactoryBot.define do
  factory :ai_namespace_feature_setting, class: '::Ai::ModelSelection::NamespaceFeatureSetting' do
    association :namespace, factory: :group

    add_attribute(:feature) { :code_completions }

    offered_model_ref { 'claude_sonnet_3_7' }
    offered_model_name { 'Claude Sonnet 3.7' }

    model_definitions do
      {
        "models" => [
          { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
          { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude_sonnet_3_7' },
          { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude-3-7-sonnet-20250219' },
          { 'name' => 'Claude 3.5 Sonnet', 'identifier' => 'claude-3-5-sonnet-20240620' },
          { 'name' => 'Claude Sonnet 3.7 20250219', 'identifier' => 'claude_sonnet_3_7_20250219' },
          { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' },
          { 'name' => 'Claude Sonnet 4.0 20250514', 'identifier' => 'claude_sonnet_4_20250514' },
          { 'name' => 'Fireworks Codestral', 'identifier' => 'codestral_2501_fireworks' },
          { 'name' => 'Vertex Codestral 2501', 'identifier' => 'codestral_2501_vertex' },
          { 'name' => 'Vertex Codestral 2508', 'identifier' => 'codestral_2508_vertex' }
        ],
        "unit_primitives" => [
          {
            "feature_setting" => "code_completions",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[
              claude_sonnet_3_5
              claude_sonnet_3_7
              openai_chatgpt_4o
              claude_sonnet_3_7_20250219
              codestral_2501_fireworks
              codestral_2501_vertex
              codestral_2508_vertex
            ],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "code_generations",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[claude_sonnet_3_5 claude_sonnet_3_7 openai_chatgpt_4o],
            "beta_models" => [],
            "unit_primitives" => ["generate_code"]
          },
          {
            "feature_setting" => "duo_chat_explain_code",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["explain_code"]
          },
          {
            "feature_setting" => "duo_chat",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude_3_5_sonnet_20240620],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "summarize_new_merge_request",
            "default_model" => "claude_sonnet_3_7_20250219",
            "selectable_models" => %w[claude_sonnet_3_7_20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["summarize_new_merge_request"]
          },
          {
            "feature_setting" => "generate_commit_message",
            "default_model" => "claude_sonnet_3_7_20250219",
            "selectable_models" => %w[claude_sonnet_3_7_20250219 claude_3_5_sonnet_20240620 claude_sonnet_4_20250514],
            "beta_models" => [],
            "unit_primitives" => ["generate_commit_message"]
          },
          {
            "feature_setting" => "resolve_vulnerability",
            "default_model" => "claude_sonnet_3_7",
            "selectable_models" => %w[claude_sonnet_3_7 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["resolve_vulnerability"]
          },
          {
            "feature_setting" => "summarize_review",
            "default_model" => "claude_sonnet_3_7",
            "selectable_models" => %w[claude_sonnet_3_7 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["summarize_review"]
          },
          {
            "feature_setting" => "review_merge_request",
            "default_model" => "claude_sonnet_3_7",
            "selectable_models" => %w[claude_sonnet_3_7 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["review_merge_request"]
          },
          {
            "feature_setting" => "review_merge_request_dap",
            "default_model" => "claude_sonnet_3_7",
            "selectable_models" => %w[claude_sonnet_3_7 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "duo_agent_platform",
            "default_model" => "claude_sonnet_4_20250514",
            "selectable_models" => %w[
              claude_sonnet_3_7_20250219
              claude_sonnet_4_20250514
            ],
            "beta_models" => [],
            "unit_primitives" => ["duo_agent_platform"]
          },
          {
            "feature_setting" => "duo_agent_platform_agentic_chat",
            "default_model" => "claude_sonnet_4_20250514",
            "selectable_models" => %w[
              claude_sonnet_3_7_20250219
              claude_sonnet_4_20250514
            ],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "sast_vulnerability_fp_detection",
            "default_model" => "claude_sonnet_3_7",
            "selectable_models" => %w[claude_sonnet_3_7 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          }
        ]
      }
    end

    trait :with_allowlist do
      model_allowlist_enabled { true }
      model_allowlist_gitlab_model_refs { %w[claude_sonnet_4_20250514 claude_sonnet_3_7_20250219] }
    end
  end
end
