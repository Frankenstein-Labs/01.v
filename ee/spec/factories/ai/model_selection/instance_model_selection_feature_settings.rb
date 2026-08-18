# frozen_string_literal: true

FactoryBot.define do
  factory :instance_model_selection_feature_setting,
    class: 'Ai::ModelSelection::InstanceModelSelectionFeatureSetting' do
    add_attribute(:feature) { :code_generations }

    offered_model_ref { 'claude-3-7-sonnet-20250219' }
    offered_model_name { 'Claude Sonnet 3.7' }

    model_definitions do
      {
        "models" => [
          { 'name' => 'Claude Sonnet 3.5', 'identifier' => 'claude_sonnet_3_5' },
          { 'name' => 'Claude Sonnet 3.7', 'identifier' => 'claude-3-7-sonnet-20250219' },
          { 'name' => 'Claude 3.7 Sonnet 20250219', 'identifier' => 'claude-3-7-sonnet-20250219' },
          { 'name' => 'Claude 3.5 Sonnet 20240620', 'identifier' => 'claude-3-5-sonnet-20240620' },
          { 'name' => 'OpenAI Chat GPT 4o', 'identifier' => 'openai_chatgpt_4o' },
          { 'name' => 'Claude Sonnet 4.0 20250514', 'identifier' => 'claude_sonnet_4_20250514' },
          { 'name' => 'Fireworks Codestral', 'identifier' => 'codestral_2501_fireworks' },
          { 'name' => 'Vertex Codestral 2501', 'identifier' => 'codestral_2501_vertex' },
          { 'name' => 'Vertex Codestral 2508', 'identifier' => 'codestral_2508_vertex' }
        ],
        "unit_primitives" => [
          {
            "feature_setting" => "code_generations",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[claude_sonnet_3_5 claude-3-7-sonnet-20250219 openai_chatgpt_4o],
            "beta_models" => [],
            "unit_primitives" => ["generate_code"]
          },
          {
            "feature_setting" => "code_completions",
            "default_model" => "claude_sonnet_3_5",
            "selectable_models" => %w[claude_sonnet_3_5 claude-3-7-sonnet-20250219 openai_chatgpt_4o
              codestral_2501_fireworks codestral_2501_vertex codestral_2508_vertex],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "duo_chat",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => %w[ask_build ask_commit]
          },
          {
            "feature_setting" => "duo_chat_explain_code",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["explain_code"]
          },
          {
            "feature_setting" => "generate_commit_message",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620 claude_sonnet_4_20250514],
            "beta_models" => [],
            "unit_primitives" => ["generate_commit_message"]
          },
          {
            "feature_setting" => "resolve_vulnerability",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["resolve_vulnerability"]
          },
          {
            "feature_setting" => "summarize_review",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["summarize_review"]
          },
          {
            "feature_setting" => "summarize_new_merge_request",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["summarize_new_merge_request"]
          },
          {
            "feature_setting" => "review_merge_request",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["review_merge_request"]
          },
          {
            "feature_setting" => "review_merge_request_dap",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "duo_agent_platform",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => ["duo_agent_platform"]
          },
          {
            "feature_setting" => "duo_agent_platform_agentic_chat",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "sast_vulnerability_fp_detection",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "sast_vulnerability_resolution",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          },
          {
            "feature_setting" => "secret_vulnerability_fp_detection",
            "default_model" => "claude-3-7-sonnet-20250219",
            "selectable_models" => %w[claude-3-7-sonnet-20250219 claude-3-5-sonnet-20240620],
            "beta_models" => [],
            "unit_primitives" => []
          }
        ]
      }
    end

    trait :code_generations do
      add_attribute(:feature) { :code_generations }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :code_completions do
      add_attribute(:feature) { :code_completions }
      offered_model_ref { 'claude_sonnet_3_5' }
      offered_model_name { 'Claude Sonnet 3.5' }
    end

    trait :duo_chat do
      add_attribute(:feature) { :duo_chat }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude 3.7 Sonnet 20250219' }
    end

    trait :duo_chat_explain_code do
      add_attribute(:feature) { :duo_chat_explain_code }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude 3.7 Sonnet 20250219' }
    end

    trait :generate_commit_message do
      add_attribute(:feature) { :generate_commit_message }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :resolve_vulnerability do
      add_attribute(:feature) { :resolve_vulnerability }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :sast_vulnerability_fp_detection do
      add_attribute(:feature) { :sast_vulnerability_fp_detection }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :secret_vulnerability_fp_detection do
      add_attribute(:feature) { :secret_vulnerability_fp_detection }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :sast_vulnerability_resolution do
      add_attribute(:feature) { :sast_vulnerability_resolution }
      offered_model_ref { 'claude-3-7-sonnet-20250219' }
      offered_model_name { 'Claude Sonnet 3.7' }
    end

    trait :gitlab_default do
      offered_model_ref { nil }
      offered_model_name { nil }
    end

    trait :with_custom_model do
      offered_model_ref { 'claude_sonnet_3_5' }
      offered_model_name { 'Claude Sonnet 3.5' }
    end

    trait :empty_ref do
      offered_model_ref { "" }
      offered_model_name { "" }
    end

    trait :without_model_definitions do
      model_definitions { {} }
    end

    trait :with_allowlist do
      model_allowlist_enabled { true }
      model_allowlist_gitlab_model_refs { %w[claude_sonnet_4_20250514 claude-3-7-sonnet-20250219] }
    end
  end
end
