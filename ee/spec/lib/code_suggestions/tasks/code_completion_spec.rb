# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeCompletion, feature_category: :code_suggestions do
  include GitlabSubscriptions::SaasSetAssignmentHelpers

  let(:endpoint_path) { 'v2/code/completions' }

  let(:expected_unit_primitive_name) { :complete_code }

  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => 'some content_above_cursor',
      'content_below_cursor' => 'some content_below_cursor'
    }.with_indifferent_access
  end

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'sor', content_below_cursor: 'som' } }
  end

  let(:model_engine) { nil } # set in the relevant contexts

  let(:params) do
    {
      current_file: current_file
    }
  end

  let(:unsafe_params) do
    {
      'current_file' => current_file,
      'telemetry' => [{ 'model_engine' => model_engine }]
    }.with_indifferent_access
  end

  let_it_be(:current_user) { create(:user) }

  let(:task) do
    described_class.new(
      params: params,
      unsafe_passthrough_params: unsafe_params,
      current_user: current_user
    )
  end

  let(:anthropic_model_name) { 'claude-sonnet-4-20250514' }

  let(:anthropic_prompt) do
    [
      {
        "content" => "You are a code completion tool that performs Fill-in-the-middle. Your task is to " \
          "complete the Python code between the given prefix and suffix inside the file 'test.py'.\nYour " \
          "task is to provide valid code without any additional explanations, comments, or feedback." \
          "\n\nImportant:\n- You MUST NOT output any additional human text or explanation.\n- You MUST " \
          "output code exclusively.\n- The suggested code MUST work by simply concatenating to the provided " \
          "code.\n- You MUST not include any sort of markdown markup.\n- You MUST NOT repeat or modify any " \
          "part of the prefix or suffix.\n- You MUST only provide the missing code that fits between " \
          "them.\n\nIf you are not able to complete code based on the given instructions, return an " \
          "empty result.",
        "role" => "system"
      },
      {
        "content" => "<SUFFIX>\nsome content_above_cursor\n</SUFFIX>\n" \
          "<PREFIX>\nsome content_below_cursor\n</PREFIX>",
        "role" => "user"
      }
    ]
  end

  let(:anthropic_request_body) do
    {
      'model_name' => anthropic_model_name,
      'model_provider' => 'anthropic',
      'current_file' => {
        'file_name' => 'test.py',
        'content_above_cursor' => 'sor',
        'content_below_cursor' => 'som'
      },
      'telemetry' => [{ 'model_engine' => 'anthropic' }],
      'prompt_version' => 3,
      'prompt' => anthropic_prompt
    }
  end

  before do
    stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    stub_feature_flags(
      incident_fail_over_completion_provider: false,
      # The v2-endpoint expectations below run with the v4 migration off; the v4
      # path is covered separately in the 'v4 /code/suggestions endpoint' describe.
      code_completion_v4_endpoint: false
    )
  end

  describe 'saas failover model' do
    before do
      stub_feature_flags(incident_fail_over_completion_provider: true)
    end

    let(:model_engine) { :anthropic }

    it_behaves_like 'code suggestion task' do
      let(:expected_body) { anthropic_request_body }
      let(:expected_feature_name) { :code_suggestions }
    end
  end

  describe 'saas primary models' do
    before do
      stub_feature_flags(incident_fail_over_completion_provider: false)
    end

    let(:expected_feature_name) { :code_suggestions }

    let(:model_engine) { 'telemetry-model-engine' }
    let(:request_body_without_model_details) do
      {
        "current_file" => {
          "file_name" => "test.py",
          "content_above_cursor" => "sor",
          "content_below_cursor" => "som"
        },
        "prompt_version" => 1,
        "telemetry" => [{ "model_engine" => model_engine }]
      }
    end

    context 'when using Fireworks/Codestral' do
      let(:request_body_for_fireworks_codestral) do
        request_body_without_model_details.merge(
          "model_name" => "codestral-2508",
          "model_provider" => "fireworks_ai"
        )
      end

      context 'on GitLab self-managed' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(false)
          stub_saas_features(gitlab_com_subscriptions: false)
        end

        it_behaves_like 'code suggestion task' do
          let(:expected_body) { request_body_for_fireworks_codestral }
        end
      end

      context 'on GitLab saas' do
        before do
          allow(Gitlab).to receive(:org_or_com?).and_return(true)
          stub_saas_features(gitlab_com_subscriptions: true)
        end

        let_it_be(:group1) do
          create(:group).tap do |g|
            setup_addon_purchase_and_seat_assignment(current_user, g, :duo_pro)
          end
        end

        let_it_be(:group2) do
          create(:group).tap do |g|
            setup_addon_purchase_and_seat_assignment(current_user, g, :duo_enterprise)
          end
        end

        it_behaves_like 'code suggestion task' do
          let(:expected_body) { request_body_for_fireworks_codestral }
        end
      end
    end
  end

  describe 'model switching', :saas do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    let(:params) { { current_file: current_file, project: project } }

    before_all do
      group.add_developer(current_user)
    end

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    context 'when the namespace feature setting is set to a specific Anthropic model' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'claude_sonnet_3_7_20250219',
          namespace: group
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_feature_name) { :code_suggestions }
        let(:model_engine) { nil }
        let(:expected_body) do
          unsafe_params.merge(
            model_name: 'claude_sonnet_3_7_20250219',
            model_provider: 'gitlab',
            prompt: anthropic_prompt,
            prompt_version: 3
          )
        end
      end
    end

    context 'when the namespace feature setting is set to a non-Anthropic Model' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'codestral_2501_fireworks',
          namespace: group
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_feature_name) { :code_suggestions }
        let(:model_engine) { nil }
        let(:expected_body) do
          unsafe_params.merge(
            model_name: 'codestral_2501_fireworks',
            model_provider: 'gitlab',
            prompt: nil,
            prompt_version: 3
          )
        end
      end
    end

    shared_examples_for 'uses the saas primary model for code completions' do
      it_behaves_like 'code suggestion task' do
        let(:expected_feature_name) { :code_suggestions }
        let(:model_engine) { 'anthropic' }
        let(:expected_body) do
          unsafe_params.merge(
            model_name: 'codestral-2508',
            model_provider: 'fireworks_ai',
            prompt_version: 1,
            telemetry: [{ model_engine: model_engine }]
          )
        end
      end
    end

    context 'when the namespace feature setting is set to GitLab Default' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: '',
          namespace: group
        )
      end

      # Even though a namespace feature setting is present,
      # but if the model is set to GitLab Default,
      # code completions will fallback to using the saas primary model,
      # as decided by the `saas_prompt` method
      it_behaves_like 'uses the saas primary model for code completions'
    end

    context 'when the group is configured to use a remapped deprecated model' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'codestral_2508_vertex',
          namespace: group
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_feature_name) { :code_suggestions }
        let(:expected_body) do
          unsafe_params.merge(
            model_name: 'codestral_2508_vertex',
            model_provider: 'gitlab',
            prompt: nil,
            prompt_version: 3
          )
        end
      end
    end
  end

  describe 'self-hosted model' do
    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [],
        'stream' => false
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file
      }
    end

    let(:task) do
      described_class.new(
        params: params,
        unsafe_passthrough_params: unsafe_params,
        current_user: current_user
      )
    end

    let_it_be(:ai_self_hosted_model) do
      create(:ai_self_hosted_model, model: :codellama, name: 'whatever')
    end

    context 'on setting the provider as `self_hosted`' do
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model,
          provider: :self_hosted
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) do
          {
            "current_file" => {
              "file_name" => "test.py",
              "content_above_cursor" => "sor",
              "content_below_cursor" => "som"
            },
            "telemetry" => [],
            "stream" => false,
            "model_provider" => "litellm",
            "prompt_version" => 2,
            "prompt" => nil,
            "model_endpoint" => "http://localhost:11434/v1",
            "model_identifier" => "provider/some-model",
            "model_name" => "codellama",
            "model_api_key" => "token"
          }
        end

        let(:expected_feature_name) { :code_suggestions }
      end
    end

    context 'on setting the provider as `disabled`' do
      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model,
          provider: :disabled
        )
      end

      it 'is a disabled task' do
        expect(task.feature_disabled?).to be(true)
      end
    end

    context 'when code_completions is vendored' do
      let_it_be(:ai_feature_setting) do
        create(:ai_feature_setting, :code_completions, provider: :vendored)
      end

      let(:model_details) do
        {
          "model_provider" => "gitlab",
          "model_name" => ""
        }
      end

      let(:expected_body) do
        {
          "current_file" => {
            "file_name" => "test.py",
            "content_above_cursor" => "sor",
            "content_below_cursor" => "som"
          },
          "telemetry" => [],
          "stream" => false,
          **model_details
        }
      end

      let(:expected_feature_name) { :code_suggestions }

      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      context 'and default model at the instance level' do
        it_behaves_like 'code suggestion task' do
          let(:model_details) do
            {
              "model_name" => "codestral-2508",
              "model_provider" => "fireworks_ai",
              "prompt_version" => 1
            }
          end

          let(:expected_feature_name) { :code_suggestions }
        end
      end

      context 'and vendored model is pinned' do
        it_behaves_like 'code suggestion task' do
          before do
            create(:instance_model_selection_feature_setting, feature: :code_completions,
              offered_model_ref: "claude_sonnet_3_5")
          end

          let(:model_details) do
            {
              "model_name" => "claude_sonnet_3_5",
              "model_provider" => "gitlab",
              "prompt_version" => 1
            }
          end

          let(:expected_feature_name) { :code_suggestions }
        end
      end
    end
  end

  describe 'when amazon q is connected' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
    let(:expected_unit_primitive_name) { :amazon_q_integration }

    before do
      stub_licensed_features(amazon_q: true)
      stub_current_organization(current_user.organization)
      Ai::Setting.for_organization(current_user.organization).update!(
        amazon_q_ready: true,
        amazon_q_role_arn: 'role::arn'
      )
    end

    it_behaves_like 'code suggestion task' do
      let(:expected_feature_name) { :amazon_q_integration }

      let(:expected_body) do
        unsafe_params.merge({
          model_name: 'amazon_q',
          model_provider: 'amazon_q',
          prompt_version: 2,
          role_arn: 'role::arn'
        })
      end
    end
  end

  describe 'v4 /code/suggestions endpoint' do
    let(:endpoint_path) { 'v4/code/suggestions' }
    let(:expected_feature_name) { :code_suggestions }

    # `content_above_cursor`/`content_below_cursor` are capped at MAX_CONTENT_CHARS
    # (100_000), not the stubbed AI_GATEWAY_CONTENT_SIZE, so they are not trimmed here.
    let(:code_editor_completion_component) do
      {
        type: 'code_editor_completion',
        payload: {
          file_name: 'test.py',
          content_above_cursor: 'some content_above_cursor',
          content_below_cursor: 'some content_below_cursor',
          language_identifier: 'Python',
          stream: false
        }
      }
    end

    before do
      stub_feature_flags(code_completion_v4_endpoint: true)
    end

    context 'with the GitLab-default model' do
      before do
        allow(Gitlab).to receive(:org_or_com?).and_return(false)
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it_behaves_like 'code suggestion task' do
        let(:model_engine) { 'telemetry-model-engine' }
        let(:expected_body) do
          unsafe_params.merge(prompt_components: [code_editor_completion_component])
        end
      end
    end

    context 'with a self-hosted model' do
      let(:unsafe_params) do
        { 'current_file' => current_file, 'telemetry' => [], 'stream' => false }.with_indifferent_access
      end

      let_it_be(:ai_self_hosted_model) do
        create(:ai_self_hosted_model, model: :codellama, name: 'whatever')
      end

      let_it_be(:ai_feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: ai_self_hosted_model,
          provider: :self_hosted
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_body) do
          unsafe_params.merge(
            prompt_components: [code_editor_completion_component],
            model_metadata: {
              provider: 'openai',
              name: 'codellama',
              endpoint: 'http://localhost:11434/v1',
              api_key: 'token',
              identifier: 'provider/some-model'
            }
          )
        end
      end
    end

    context 'when amazon q is connected' do
      let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :duo_amazon_q) }
      let(:expected_unit_primitive_name) { :amazon_q_integration }

      before do
        stub_licensed_features(amazon_q: true)
        stub_current_organization(current_user.organization)
        Ai::Setting.for_organization(current_user.organization).update!(
          amazon_q_ready: true,
          amazon_q_role_arn: 'role::arn'
        )
      end

      it_behaves_like 'code suggestion task' do
        let(:expected_feature_name) { :amazon_q_integration }
        let(:expected_body) do
          unsafe_params.merge(
            prompt_components: [code_editor_completion_component],
            model_metadata: {
              provider: 'amazon_q',
              name: 'amazon_q',
              role_arn: 'role::arn'
            }
          )
        end
      end
    end
  end
end
