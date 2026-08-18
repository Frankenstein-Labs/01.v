# frozen_string_literal: true

module API
  module Ai
    class ThirdPartyAgents < ::API::Base
      include APIGuard

      feature_category :duo_agent_platform

      allow_access_with_scope [:ai_features, :api]

      before do
        authenticate!

        forbidden! unless current_user.can?(:create_third_party_agent_direct_access_token)
      end

      namespace :ai do
        namespace :third_party_agents do
          resources :direct_access do
            desc 'Get connection details for third party agents' do
              detail 'Returns connection details including tokens for accessing third-party agents.'
              success code: 201
              failure [
                { code: 401, message: 'Unauthorized' },
                { code: 404, message: 'Not found' },
                { code: 503, message: 'Service unavailable' }
              ]
              tags ['gitlab_duo']
            end

            route_setting :lifecycle, :experiment
            route_setting :authorization,
              permissions: :create_third_party_agent_direct_access_token,
              boundary_type: :user
            post do
              token = ::Ai::ThirdPartyAgents::TokenService.new(
                current_user: current_user,
                organization: Current.organization
              ).direct_access_token

              service_unavailable!(token[:message]) if token[:status] == :error

              present token.payload, with: Grape::Presenters::Presenter
            end
          end
        end
      end
    end
  end
end
