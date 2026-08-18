# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeGeneration, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  let(:content_above_cursor) { 'some content_above_cursor' }
  let(:content_below_cursor) { 'some content_below_cursor' }
  let(:instruction) { CodeSuggestions::Instruction.from_trigger_type('comment') }
  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => content_above_cursor,
      'content_below_cursor' => content_below_cursor
    }.with_indifferent_access
  end

  let(:expected_unit_primitive_name) { :generate_code }

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'sor', content_below_cursor: 'som' } }
  end

  let(:client) { nil }

  subject(:task) do
    described_class.new(
      params: params,
      unsafe_passthrough_params: unsafe_params,
      client: client,
      current_user: current_user
    )
  end

  context 'when using saas anthropic model' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
      allow(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to receive(:new).and_return(anthropic_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [{ 'model_engine' => 'anthropic' }]
      }.with_indifferent_access
    end

    let(:params) do
      {
        code_generation_model_family: :anthropic,
        content_above_cursor: content_above_cursor,
        instruction: instruction,
        current_file: current_file,
        model_name: 'claude-3-5-sonnet-20240620'
      }
    end

    let(:anthropic_request_params) do
      {
        'prompt_components' => [
          {
            'type' => 'code_editor_generation',
            'payload' => {
              'file_name' => 'test.py',
              'content_above_cursor' => 'some content_above_cursor',
              'content_below_cursor' => 'some content_below_cursor',
              'language_identifier' => 'Python',
              'prompt_id' => 'code_suggestions/generations',
              'prompt_version' => '^1.0.0',
              'prompt_enhancer' => {
                'examples_array' => [
                  {
                    'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                    'response' => "return self.visibility == 'PUBLIC'",
                    'trigger_type' => 'comment'
                  },
                  {
                    'example' => "# get the current user's name from the session data\\n{{cursor}}",
                    'response' => "username = session['username']\\nreturn username",
                    'trigger_type' => 'comment'
                  }
                ],
                'trimmed_content_above_cursor' => 'some content_above_cursor',
                'trimmed_content_below_cursor' => 'some content_below_cursor',
                'related_files' => '',
                'related_snippets' => '',
                'libraries' => '',
                'user_instruction' => 'Generate the best possible code based on instructions.'
              }
            }
          }
        ]
      }
    end

    let(:anthropic_messages_prompt) do
      instance_double(
        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages,
        request_params: anthropic_request_params
      )
    end

    let(:expected_body) do
      {
        'current_file' => {
          'content_above_cursor' => 'sor',
          'content_below_cursor' => 'som',
          'file_name' => 'test.py'
        },
        'prompt_components' => [
          {
            'payload' => {
              'content_above_cursor' => 'some content_above_cursor',
              'content_below_cursor' => 'some content_below_cursor',
              'file_name' => 'test.py',
              'language_identifier' => 'Python',
              'prompt_enhancer' => {
                'examples_array' => [
                  {
                    'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                    'response' => "return self.visibility == 'PUBLIC'",
                    'trigger_type' => 'comment'
                  },
                  {
                    'example' => "# get the current user's name from the session data\\n{{cursor}}",
                    'response' => "username = session['username']\\nreturn username",
                    'trigger_type' => 'comment'
                  }
                ],
                'trimmed_content_above_cursor' => 'some content_above_cursor',
                'trimmed_content_below_cursor' => 'some content_below_cursor',
                'related_files' => '',
                'related_snippets' => '',
                'libraries' => '',
                'user_instruction' => 'Generate the best possible code based on instructions.'
              },
              'prompt_id' => 'code_suggestions/generations',
              'prompt_version' => '^1.0.0'
            },
            'type' => 'code_editor_generation'
          }
        ],
        'telemetry' => [{ 'model_engine' => 'anthropic' }]
      }
    end

    let(:expected_feature_name) { :code_suggestions }

    it 'calls code creation Anthropic' do
      task.body
      expect(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to have_received(:new).with(params, current_user, nil)
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v4/code/suggestions' }
    end
  end

  context 'when using self hosted model' do
    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [],
        'stream' => false
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        generation_type: 'empty_function'
      }
    end

    context 'on setting the provider as `self_hosted`' do
      let(:expected_feature_name) { :code_suggestions }
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :self_hosted) }

      it_behaves_like 'code suggestion task' do
        let(:endpoint_path) { 'v4/code/suggestions' }
        let(:expected_body) do
          {
            'current_file' => {
              'content_above_cursor' => 'some content_above_cursor',
              'content_below_cursor' => 'some content_below_cursor',
              'file_name' => 'test.py'
            },
            'prompt_components' => [
              {
                'payload' => {
                  'content_above_cursor' => 'some content_above_cursor',
                  'content_below_cursor' => 'some content_below_cursor',
                  'file_name' => 'test.py',
                  'language_identifier' => 'Python',
                  'prompt_enhancer' => {
                    "examples_array" => [
                      {
                        "example" => "class Project:\n  " \
                          "def __init__(self, name, public):\n    " \
                          "self.name = name\n    " \
                          "self.visibility = 'PUBLIC' if public\n\n    " \
                          "# is this project public?\n" \
                          "{{cursor}}\n\n    " \
                          "# print name of this project",
                        "response" => "<new_code>def is_public(self):\n  return self.visibility == 'PUBLIC'",
                        "trigger_type" => "comment"
                      },
                      {
                        "example" => "def get_user(session):\n  # get the current user's name from the session data\n" \
                          "{{cursor}}\n\n# is the current user an admin",
                        "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                          "session['username']\nreturn username",
                        "trigger_type" => "comment"
                      },
                      {
                        "example" => "class Project:\n  def __init__(self, name, public):\n{{cursor}}",
                        "response" => "<new_code>self.name = name\nself.visibility = 'PUBLIC' if public",
                        "trigger_type" => "empty_function"
                      },
                      {
                        "example" => "# get the current user's name from the session data\ndef get_user(session):\n" \
                          "{{cursor}}\n\n# is the current user an admin",
                        "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                          "session['username']\nreturn username",
                        "trigger_type" => "empty_function"
                      }
                    ],
                    'trimmed_content_above_cursor' => 'some content_above_cursor',
                    'trimmed_content_below_cursor' => 'some content_below_cursor',
                    "libraries" => [],
                    "related_files" => [],
                    "related_snippets" => [],
                    'user_instruction' => 'Generate the best possible code based on instructions.'
                  },
                  'prompt_id' => 'code_suggestions/generations',
                  'prompt_version' => '^1.0.0',
                  'stream' => false
                },
                'type' => 'code_editor_generation'
              }
            ],
            "model_metadata" => {
              "api_key" => "token",
              "endpoint" => "http://localhost:11434/v1",
              "identifier" => "provider/some-model",
              "name" => "mistral",
              "provider" => "openai"
            },
            'stream' => false,
            'telemetry' => []
          }
        end
      end
    end

    context 'on setting the provider as `disabled`' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :disabled) }

      it 'is a disabled task' do
        expect(task.feature_disabled?).to be(true)
      end
    end
  end

  context 'when amazon q is connected' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
    let(:expected_unit_primitive_name) { :amazon_q_integration }

    let(:unsafe_params) do
      {
        "prompt_components" => [
          {
            "type" => 'code_editor_generation',
            "payload" => {
              "content_above_cursor" => "some content_above_cursor",
              "content_below_cursor" => "some content_below_cursor",
              "file_name" => "test.py",
              "language_identifier" => "Python",
              "prompt_enhancer" => {},
              "prompt_id" => "code_suggestions/generations",
              "prompt_version" => "2.0.0",
              "stream" => false
            }
          }
        ]
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        generation_type: 'empty_function'
      }
    end

    before do
      stub_licensed_features(amazon_q: true)
      stub_current_organization(current_user.organization)
      Ai::Setting.for_organization(current_user.organization).update!(
        amazon_q_ready: true,
        amazon_q_role_arn: 'role::arn'
      )
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v4/code/suggestions' }
      let(:expected_feature_name) { :amazon_q_integration }

      let(:expected_body) do
        {
          "prompt_components" => [
            {
              "type" => 'code_editor_generation',
              "payload" => {
                "content_above_cursor" => "some content_above_cursor",
                "content_below_cursor" => "some content_below_cursor",
                "file_name" => "test.py",
                "language_identifier" => "Python",
                "stream" => false,
                "prompt_id" => 'code_suggestions/generations',
                "prompt_version" => "^1.0.0",
                'prompt_enhancer' => {
                  "examples_array" => [
                    {
                      "example" => "class Project:\n  " \
                        "def __init__(self, name, public):\n    " \
                        "self.name = name\n    " \
                        "self.visibility = 'PUBLIC' if public\n\n    " \
                        "# is this project public?\n" \
                        "{{cursor}}\n\n    " \
                        "# print name of this project",
                      "response" => "<new_code>def is_public(self):\n  return self.visibility == 'PUBLIC'",
                      "trigger_type" => "comment"
                    },
                    {
                      "example" => "def get_user(session):\n  # get the current user's name from the session data\n" \
                        "{{cursor}}\n\n# is the current user an admin",
                      "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                        "session['username']\nreturn username",
                      "trigger_type" => "comment"
                    },
                    {
                      "example" => "class Project:\n  def __init__(self, name, public):\n{{cursor}}",
                      "response" => "<new_code>self.name = name\nself.visibility = 'PUBLIC' if public",
                      "trigger_type" => "empty_function"
                    },
                    {
                      "example" => "# get the current user's name from the session data\ndef get_user(session):\n" \
                        "{{cursor}}\n\n# is the current user an admin",
                      "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                        "session['username']\nreturn username",
                      "trigger_type" => "empty_function"
                    }
                  ],
                  'trimmed_content_above_cursor' => 'some content_above_cursor',
                  'trimmed_content_below_cursor' => 'some content_below_cursor',
                  "libraries" => [],
                  "related_files" => [],
                  "related_snippets" => [],
                  'user_instruction' => 'Generate the best possible code based on instructions.'
                }
              }
            }
          ],
          "model_metadata" => {
            "name" => "amazon_q",
            "provider" => "amazon_q",
            "role_arn" => "role::arn"
          }
        }
      end
    end
  end

  context 'on using namespace level model selection', :saas do
    let_it_be(:root_namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: root_namespace) }
    let_it_be(:feature_setting) do
      create(:ai_namespace_feature_setting, namespace: root_namespace, feature: 'code_generations',
        offered_model_ref: 'claude_sonnet_3_5')
    end

    let(:unsafe_params) do
      {
        "prompt_components" => [
          {
            "type" => 'code_editor_generation',
            "payload" => {
              "content_above_cursor" => "some content_above_cursor",
              "content_below_cursor" => "some content_below_cursor",
              "file_name" => "test.py",
              "language_identifier" => "Python",
              "prompt_enhancer" => {},
              "prompt_id" => "code_suggestions/generations",
              "prompt_version" => "^1.0.0",
              "stream" => false
            }
          }
        ]
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        generation_type: 'empty_function',
        project: project
      }
    end

    before_all do
      root_namespace.add_developer(current_user)
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v4/code/suggestions' }
      let(:expected_feature_name) { :code_suggestions }

      let(:expected_body) do
        {
          'model_metadata' => {
            'feature_setting' => 'code_generations',
            'identifier' => 'claude_sonnet_3_5',
            'provider' => 'gitlab'
          },
          'prompt_components' => [
            {
              'type' => 'code_editor_generation',
              'payload' => {
                'content_above_cursor' => 'some content_above_cursor',
                'content_below_cursor' => 'some content_below_cursor',
                'file_name' => 'test.py',
                'language_identifier' => 'Python',
                'prompt_enhancer' => {
                  "examples_array" => [
                    {
                      "example" => "class Project:\n  " \
                        "def __init__(self, name, public):\n    " \
                        "self.name = name\n    " \
                        "self.visibility = 'PUBLIC' if public\n\n    " \
                        "# is this project public?\n" \
                        "{{cursor}}\n\n    " \
                        "# print name of this project",
                      "response" => "<new_code>def is_public(self):\n  return self.visibility == 'PUBLIC'",
                      "trigger_type" => "comment"
                    },
                    {
                      "example" => "def get_user(session):\n  # get the current user's name from the session data\n" \
                        "{{cursor}}\n\n# is the current user an admin",
                      "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                        "session['username']\nreturn username",
                      "trigger_type" => "comment"
                    },
                    {
                      "example" => "class Project:\n  def __init__(self, name, public):\n{{cursor}}",
                      "response" => "<new_code>self.name = name\nself.visibility = 'PUBLIC' if public",
                      "trigger_type" => "empty_function"
                    },
                    {
                      "example" => "# get the current user's name from the session data\ndef get_user(session):\n" \
                        "{{cursor}}\n\n# is the current user an admin",
                      "response" => "<new_code>username = None\nif 'username' in session:\n  username = " \
                        "session['username']\nreturn username",
                      "trigger_type" => "empty_function"
                    }
                  ],
                  "libraries" => [],
                  "related_files" => [],
                  "related_snippets" => [],
                  "trimmed_content_above_cursor" => "some content_above_cursor",
                  "trimmed_content_below_cursor" => "some content_below_cursor",
                  "user_instruction" => "Generate the best possible code based on instructions."
                },
                'prompt_id' => 'code_suggestions/generations',
                'prompt_version' => '^1.0.0',
                'stream' => false
              }
            }
          ]
        }
      end
    end
  end
end
