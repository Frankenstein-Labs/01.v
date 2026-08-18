# frozen_string_literal: true

require 'spec_helper'
RSpec.describe ApplicationController, type: :request, feature_category: :shared do
  include TermsHelper
  context 'with redirection due to onboarding', feature_category: :onboarding do
    let(:onboarding_in_progress) { true }
    let(:url) { '_onboarding_step_' }
    let(:onboarding_status_step_url) { url }
    let(:user) do
      create(
        :user,
        onboarding_in_progress: onboarding_in_progress,
        onboarding_status_step_url: onboarding_status_step_url
      )
    end

    before do
      sign_in(user)
    end

    context 'when onboarding feature is available' do
      before do
        stub_saas_features(onboarding: true)
      end

      context 'when onboarding is enabled' do
        context 'and onboarding step url does not match current request url' do
          where(:url, :params) do
            [
              ["/group/new", {}],
              ["/?query=param", { test: 456 }],
              ["http://gitlab.com/next/steps", {}],
              ["http://gitlab.com/next/steps?test=param", { test: "param" }]
            ]
          end

          with_them do
            it 'redirects to onboarding step url' do
              get root_path, params: params

              expect(response).to redirect_to(url)
            end
          end
        end

        context 'and onboarding step url matches current request url' do
          where(:url, :params) do
            [
              ["/?query=param", { query: "param" }],
              ["/?q1=1&q2=2", { q1: 1, q2: 2 }],
              ["#{Gitlab.config.gitlab.url}/", {}],
              ["#{Gitlab.config.gitlab.url}/?query=param", { query: "param" }]
            ]
          end

          with_them do
            it 'does not redirect to onboarding step url' do
              get root_path, params: params

              expect(response).not_to be_redirect
            end
          end
        end

        context 'when onboarding step url is not set' do
          let(:onboarding_status_step_url) { nil }

          it 'does not redirect for a request away from onboarding' do
            get root_path

            expect(response).not_to be_redirect
          end
        end

        context 'when welcome step has been completed and step_url is still welcome' do
          let(:onboarding_status_step_url) { users_sign_up_welcome_path }

          before do
            user.update!(onboarding_status_setup_for_company: true)
          end

          context 'for environments with replicas' do
            before do
              allow(User.connection.load_balancer.host)
                .to receive_messages(host: 'host', database_replica_location: 'ABC')
            end

            it 'does not redirect for a request away from onboarding and tracks the error' do
              expect(Gitlab::ErrorTracking)
                .to receive(:track_exception).with(
                  instance_of(::Onboarding::StepUrlError),
                  onboarding_status: user.onboarding_status.to_json,
                  onboarding_in_progress: user.onboarding_in_progress,
                  db_host: instance_of(String),
                  db_lsn: instance_of(String)
                )

              expect { get root_path }.to change { user.reload.onboarding_in_progress }.to(false)

              expect(response).not_to be_redirect
            end

            context 'when this differs from what is in cache', :use_clean_rails_memory_store_caching do
              before do
                Rails.cache.write("user_onboarding_in_progress:#{user.id}", false)
              end

              it 'does not redirect for a request away from onboarding and tracks the error' do
                expect(Gitlab::ErrorTracking).to receive(:track_exception) do |exception, metadata|
                  expect(exception).to be_a(::Onboarding::StepUrlError)
                  expect(exception.message).to include('and their onboarding has already been marked')

                  result_metadata = {
                    onboarding_status: user.onboarding_status.to_json,
                    onboarding_in_progress: user.onboarding_in_progress,
                    db_host: 'host',
                    db_lsn: 'ABC'
                  }
                  expect(metadata).to eq(result_metadata)
                end

                expect { get root_path }.to change { user.reload.onboarding_in_progress }.to(false)

                expect(response).not_to be_redirect
              end
            end
          end

          context 'for environments without replicas' do
            it 'does not redirect for a request away from onboarding and tracks the error' do
              expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

              expect { get root_path }.to change { user.reload.onboarding_in_progress }.to(false)

              expect(response).not_to be_redirect
            end
          end

          context 'when stop_welcome_redirection feature is not enabled' do
            before do
              stub_feature_flags(stop_welcome_redirection: false)
            end

            it 'redirects away from requested path and does not finish onboarding' do
              expect { get root_path }.not_to change { user.reload.onboarding_in_progress }

              expect(response).to be_redirect
            end
          end

          context 'when the step_url carries the migrating marker' do
            let(:onboarding_status_step_url) { "#{users_sign_up_welcome_path}?migrating=true" }

            it 'redirects the user back to welcome without finishing onboarding' do
              expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

              expect { get root_path }.not_to change { user.reload.onboarding_in_progress }.from(true)

              expect(response).to redirect_to(onboarding_status_step_url)
            end
          end
        end

        context 'when terms enabled' do
          it 'redirects to terms first' do
            enforce_terms
            get root_path

            expect(response).to have_gitlab_http_status :redirect
            expect(response).to redirect_to(terms_path({ redirect: root_path }))

            follow_redirect!

            expect(response).to have_gitlab_http_status :ok
            expect(response.body).to include 'These are the terms'
          end
        end

        context 'when qualifying for 2fa' do
          it 'redirects to the onboarding step' do
            create_two_factor_group_with_user(user)

            get root_path

            expect(response).to redirect_to(url)
          end
        end

        context 'when request path equals redirect path' do
          let(:url) { root_path }

          it 'does not redirect to the onboarding step' do
            get root_path

            expect(response).not_to be_redirect
          end
        end

        context 'with non-get request' do
          it 'does not redirect to the onboarding step' do
            expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |instance|
              expect(instance).to receive(:execute).and_return(ServiceResponse.success)
            end

            post users_sign_up_company_path
          end
        end

        context 'when referer is about:blank' do
          it 'does not raise an error and redirects to onboarding step' do
            expect do
              get root_path, headers: { 'HTTP_REFERER' => 'about:blank' }
            end.not_to raise_error

            expect(response).to redirect_to(url)
          end
        end

        context 'when referer URI has no path' do
          it 'does not raise an error and redirects to onboarding step' do
            expect do
              get root_path, headers: { 'HTTP_REFERER' => 'mailto:user@example.com' }
            end.not_to raise_error

            expect(response).to redirect_to(url)
          end
        end
      end

      context 'when onboarding is disabled' do
        let(:onboarding_in_progress) { false }

        it 'does not redirect to the onboarding step' do
          get root_path

          expect(response).not_to be_redirect
        end

        context 'when qualifying for 2fa' do
          it 'redirects to 2fa setup' do
            create_two_factor_group_with_user(user)

            get root_path

            expect(response).to redirect_to(profile_two_factor_auth_path)
          end
        end
      end
    end

    context 'when onboarding feature is not available' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not redirect to the onboarding step' do
        get root_path

        expect(response).not_to be_redirect
      end

      context 'when qualifying for 2fa' do
        it 'redirects to 2fa setup' do
          create_two_factor_group_with_user(user)

          get root_path

          expect(response).to redirect_to(profile_two_factor_auth_path)
        end
      end
    end

    def create_two_factor_group_with_user(user)
      create(:group, require_two_factor_authentication: true) do |g|
        g.add_developer(user)
        user.reset
      end
    end
  end
end
