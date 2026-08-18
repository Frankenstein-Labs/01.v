# frozen_string_literal: true

module API
  class CodeSuggestions < ::API::Base
    include APIGuard
    include Helpers

    feature_category :code_suggestions

    MAX_CONTEXT_TYPE_SIZE = 255
    # a limit used for overall body size when forwarding request to ai-assist
    MAX_BODY_SIZE = ::Ai::AdditionalContext::MAX_BODY_SIZE
    MAX_CONTENT_SIZE = 400_000

    allow_access_with_scope :ai_features

    before do
      authenticate!

      not_found_with_origin_header! unless Feature.enabled?(:ai_duo_code_suggestions_switch, type: :ops)

      unauthorized_with_origin_header! unless current_user.can?(:access_code_suggestions)
    end

    helpers do
      include Gitlab::Utils::StrongMemoize

      def completion_model_details(project_path = nil)
        root_namespace = project(project_path)&.root_namespace if project_path.present?

        ::CodeSuggestions::ModelDetails::CodeCompletion.new(
          current_user: current_user,
          root_namespace: root_namespace
        )
      end

      def project(project_path)
        strong_memoize_with(:project, project_path) do
          ::ProjectsFinder
            .new(
              params: { full_paths: [project_path] },
              current_user: current_user
            ).execute.first
        end
      end

      # Once the feature flag is removed, fold this into a subject-scoped
      # :access_code_suggestions policy, to match how Duo Chat checks access.
      def duo_disabled_for_request?(project_path)
        # nil when the path is unknown to us or the user cannot read it. We then fall
        # back to the governing namespace, which is where the usage is billed, and
        # which is what the rest of this endpoint already resolves the request to.
        scope = project(project_path) if project_path.present?

        current_user.code_suggestions_blocked_for?(scope)
      end

      def push_feature_flag_headers
        Gitlab::AiGateway.push_feature_flag(:expanded_ai_logging, current_user)
        Gitlab::AiGateway.push_feature_flag(:ai_gateway_multi_default_models, current_user)
      end

      def ai_gateway_headers(headers, task, project_path)
        project = project(project_path) if project_path.present?
        Gitlab::AiGateway.headers(
          user: current_user,
          unit_primitive_name: task.unit_primitive_name,
          namespace_id: project&.namespace_id,
          project_id: project&.id,
          governing_namespace_id: current_user.governing_namespace(project)&.id,
          ai_feature_name: :code_suggestions,
          agent: headers["User-Agent"],
          lsp_version: headers["X-Gitlab-Language-Server-Version"],
          organization_id: get_current_organization_id
        ).merge(saas_headers).merge(model_config_headers(project)).transform_values { |v| Array(v) }
      end

      def ai_gateway_public_headers(ai_feature_name, service_name, project_path)
        project = project(project_path) if project_path.present?
        Gitlab::AiGateway.public_headers(
          user: current_user, ai_feature_name: ai_feature_name, unit_primitive_name: service_name,
          governing_namespace_id: current_user.governing_namespace(project)&.id, project_id: project&.id,
          organization_id: get_current_organization_id)
          .merge(saas_headers)
          .merge(model_config_headers(project))
          .merge('X-Gitlab-Authentication-Type' => 'oidc')
      end

      def saas_headers
        return {} unless Gitlab.com?

        all_duo_namespace_ids = current_user.duo_available_namespace_ids +
          current_user.duo_core_ids_via_namespace_settings

        all_duo_namespace_ids = all_duo_namespace_ids.compact.uniq

        {
          'X-Gitlab-Saas-Namespace-Ids' => '', # TODO: remove this header entirely once confirmed safe to do so
          # We're reusing the existing 'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' header name
          # even though we're now combining duo_pro, duo_enterprise and duo_core namespace IDs.
          # This avoids the need for the data team to combine columns in reporting,
          # allowing the existing reporting pipeline to continue working seamlessly.
          'X-Gitlab-Saas-Duo-Pro-Namespace-Ids' => all_duo_namespace_ids.join(',')
        }
      end

      def model_config_headers(project)
        model_prompt_cache_enabled = model_prompt_cache_enabled?(project)

        {
          # this config will decide if we allow the underlying model to cache the generated completion response
          'X-Gitlab-Model-Prompt-Cache-Enabled' => (!!model_prompt_cache_enabled).to_s
        }
      end

      def not_found_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        not_found!
      end

      def unauthorized_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        unauthorized!
      end

      def file_too_large_with_origin_header!
        header('X-GitLab-Error-Origin', 'monolith')
        file_too_large!
      end

      def forbid_direct_access?
        return true if Gitlab::CurrentSettings.disabled_direct_code_suggestions
        return true if Feature.enabled?(:incident_fail_over_completion_provider, current_user)
        return true if ::Ai::AmazonQ.connected?
        return true if ::Ai::SelfHostedDapBilling.self_hosted_dap_billing_enabled?

        false
      end

      def get_current_organization_id
        Current.organization.id if Current.organization_assigned
      end

      def model_prompt_cache_enabled?(current_project)
        if current_project.present?
          current_project.model_prompt_cache_enabled
        else
          Gitlab::CurrentSettings.model_prompt_cache_enabled
        end
      end
    end

    namespace 'code_suggestions' do
      resources :completions do
        desc 'Generate code completions' do
          detail 'Generates code completions. Uses the AI abstraction layer to generate code completions. Requests ' \
            'to this endpoint are proxied to the AI Gateway.'
          success code: 200
          tags %w[code_suggestions]
        end

        params do
          requires :current_file, type: Hash, desc: 'Object that contains information about the current file' do
            requires :file_name, type: String, limit: 255, desc: 'The name of the current file'
            requires :content_above_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content above cursor'
            optional :content_below_cursor, type: String, limit: MAX_CONTENT_SIZE, desc: 'The content below cursor'
          end
          optional :intent, type: String, values:
            [
              ::CodeSuggestions::InstructionsExtractor::INTENT_COMPLETION,
              ::CodeSuggestions::InstructionsExtractor::INTENT_GENERATION
            ],
            desc: 'The intent of the completion request, current options are "completion" or "generation"'
          optional :generation_type, type: String, values: ::CodeSuggestions::Instruction::GENERATION_TRIGGER_TYPES,
            desc: 'The type of generation request'
          optional :stream, type: Boolean, default: false, desc: 'The option to stream code completion response'
          optional :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
          optional :user_instruction, type: String, limit: MAX_BODY_SIZE,
            desc: 'Additional instructions provided by a user'
          optional :context, type: Array, allow_blank: false, desc: 'List of related context parts' do
            requires :type, type: String,
              values: ::Ai::AdditionalContext::CODE_SUGGESTIONS_CONTEXT_TYPES.values,
              desc: 'The type of a related part of context'
            requires :name, type: String, limit: MAX_CONTEXT_TYPE_SIZE, allow_blank: false,
              desc: 'The name of a related part of context'
            requires :content, type: String, limit: MAX_BODY_SIZE, allow_blank: false,
              desc: 'The content of a part of context'
          end
        end
        route_setting :authorization, permissions: :create_code_suggestion_completion, boundary_type: :user
        post do
          verify_workhorse_api!
          check_rate_limit!(:code_suggestions_api_endpoint, scope: current_user) do
            Gitlab::InternalEvents.track_event('code_suggestions_rate_limit_exceeded', user: current_user)

            header('X-GitLab-Error-Origin', 'monolith')
          end

          task = ::CodeSuggestions::TaskFactory.new(
            current_user,
            client: ::CodeSuggestions::Client.new(headers),
            params: declared_params(params),
            unsafe_passthrough_params: params.except(:private_token)
          ).task

          if task.duo_context_not_found?
            msg = _("I'm sorry, you have not selected a default GitLab Duo namespace. " \
              "Please go to GitLab and in user Preferences - Behavior, select a default namespace for GitLab Duo.")

            render_structured_api_error!({
              'error' => 'missing_default_duo_group',
              'error_description' => msg,
              'message' => { error: msg }
            }, 422)
          end

          unauthorized_with_origin_header! if task.feature_disabled?

          unless current_user.allowed_to_use?(:code_suggestions,
            unit_primitive_name: task.unit_primitive_name,
            licensed_feature: task.licensed_feature
          )
            unauthorized_with_origin_header!
          end

          unauthorized_with_origin_header! if duo_disabled_for_request?(declared_params[:project_path])

          body = task.body
          file_too_large_with_origin_header! if body.size > MAX_BODY_SIZE

          # we add expanded_ai_logging to header only if current user is internal user,
          push_feature_flag_headers

          project_path = declared_params[:project_path]

          billing_result = ::Ai::CodeSuggestions::SelfHostedBillingTracker.new(
            current_user: current_user,
            feature_setting: task.feature_setting
          ).track

          render_structured_api_error!({ 'message' => billing_result.message }, 403) unless billing_result.success?

          workhorse_headers =
            Gitlab::Workhorse.send_url(
              task.endpoint,
              body: body,
              headers: ai_gateway_headers(headers, task, project_path),
              method: "POST",
              timeouts: { read: 55 }
            )

          header(*workhorse_headers)

          status :ok
          body ''
        end
      end

      resources :direct_access do
        desc 'Retrieve direct connection details for the AI Gateway' do
          detail 'Retrieves user-specific connection details which can be used by IDEs or clients to send ' \
            '`completion` requests to Code Suggestions directly through the AI Gateway.'
          success code: 201
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
          tags %w[code_suggestions]
        end

        params do
          optional :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
        end
        route_setting :authorization, permissions: :create_code_suggestion_direct_access, boundary_type: :user
        post do
          project_path = declared_params[:project_path]

          forbidden!('Direct connections are disabled') if forbid_direct_access?

          # Must precede token minting: the AI Gateway self-signs these tokens and
          # cannot revoke them, so one issued here keeps working, and billing.
          unauthorized! if duo_disabled_for_request?(project_path)

          check_rate_limit!(:code_suggestions_direct_access, scope: current_user) do
            Gitlab::InternalEvents.track_event('code_suggestions_direct_access_rate_limit_exceeded', user: current_user)
          end

          model_details = completion_model_details(project_path)

          unauthorized! if model_details.feature_disabled?

          if Gitlab.com? && !current_user.belongs_to_paid_namespace?(exclude_trials: true)
            forbidden!(
              'Code suggestions tokens can only be generated for users belonging to paid, non-trial namespaces'
            )
          end

          if model_details.duo_context_not_found?
            msg = _("I'm sorry, you have not selected a default GitLab Duo namespace. " \
              "Please go to GitLab and in user Preferences - Behavior, select a default namespace for GitLab Duo.")

            render_structured_api_error!({
              'error' => 'missing_default_duo_group',
              'error_description' => msg,
              'message' => { error: msg }
            }, 422)
          end

          current_project = project(project_path) if project_path.present?

          # Request the token only after all checks pass. The Duo context
          # check above returns 422 when the user has no governing
          # namespace. This prevents a token request without a root
          # namespace, which the usage billing check would deny.
          push_feature_flag_headers
          token = Gitlab::Llm::AiGateway::CodeSuggestionsClient
            .new(current_user, project: current_project)
            .direct_access_token

          if token[:status] == :error
            render_structured_api_error!({
              'message' => token[:message],
              'error_description' => token.dig(:context, :message),
              'error_code' => token.dig(:context, :error_code),
              'error' => token.dig(:context, :error)
            }, token.dig(:context, :response_code) || 503)
          end

          details_hash = model_details.current_model

          access = {
            base_url: model_details.base_url,
            # for development purposes we just return instance JWT, this should not be used in production
            # until we generate a short-term token for user
            # https://gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/-/issues/429
            token: token[:token],
            expires_at: token[:expires_at],
            headers: ai_gateway_public_headers(
              model_details.feature_name,
              model_details.unit_primitive_name,
              project_path
            )
          }.tap do |a|
            a[:model_details] = details_hash unless details_hash.blank?
          end

          present access, with: Grape::Presenters::Presenter
        end
      end

      resources :enabled do
        desc 'Validate status of Code Suggestions' do
          detail 'Validates the status Code Suggestions for a specified project. This checks if the project ' \
            'has `code_suggestions` enabled or if an ancestor group has the Code Suggestions add-on enabled.'
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: '403 Code Suggestions Disabled' },
            { code: 404, message: 'Not found' }
          ]
          tags %w[code_suggestions]
        end
        params do
          requires :project_path, type: String, desc: 'The path of the project',
            documentation: { example: 'namespace/project' }
        end

        route_setting :authorization, permissions: :read_code_suggestion_enabled,
          boundary_type: :project, boundary_param: :project_path
        post do
          path = declared_params[:project_path]

          not_found! if path.empty?

          projects = ::ProjectsFinder.new(params: { full_paths: [path] }, current_user: current_user).execute

          not_found! if projects.none?

          forbidden! unless projects.first.project_setting.duo_features_enabled?

          status :ok
        end
      end

      resources :connection_details do
        desc 'Retrieve connection details' do
          detail 'Retrieves user-specific connection details which can be used by IDEs or clients for telemetry, ' \
            'including an instance-specific application ID, application access token, and clickhouse data plane URL.'
          success code: 201
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not found' },
            { code: 429, message: 'Too many requests' }
          ]
          tags %w[code_suggestions]
        end

        route_setting :authorization, permissions: :read_code_suggestion_connection_detail, boundary_type: :user
        post do
          unauthorized! if completion_model_details.feature_disabled?

          check_rate_limit!(:code_suggestions_connection_details, scope: current_user) do
            Gitlab::InternalEvents.track_event(
              'code_suggestions_connection_details_rate_limit_exceeded', user: current_user
            )
          end

          aigw_headers = Gitlab::AiGateway.public_headers(
            user: current_user,
            ai_feature_name: completion_model_details.feature_name,
            unit_primitive_name: completion_model_details.unit_primitive_name,
            organization_id: get_current_organization_id
          )

          details = {
            instance_id: aigw_headers['x-gitlab-instance-id'],
            instance_version: Gitlab.version_info.to_s,
            realm: aigw_headers['x-gitlab-realm'],
            global_user_id: aigw_headers['x-gitlab-global-user-id'],
            host_name: aigw_headers['x-gitlab-host-name'],
            feature_enablement_type: aigw_headers['x-gitlab-feature-enablement-type'],
            saas_duo_pro_namespace_ids:
              saas_headers['X-Gitlab-Saas-Duo-Pro-Namespace-Ids'].to_s.split(',').compact.map(&:to_i)
          }

          present details, with: Grape::Presenters::Presenter
        end
      end
    end
  end
end
