# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::StatusCreateService, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }

    let(:current_user) { user }
    let(:step_url) { 'foobar' }
    let(:params) { { glm_content: 'glm_content', glm_source: 'glm_source' } }
    let(:user_return_to) { nil }
    let(:onboarding_status) do
      {
        step_url: step_url,
        initial_registration_type: 'free',
        registration_type: 'free',
        glm_content: 'glm_content',
        glm_source: 'glm_source'
      }
    end

    let(:service) { described_class.new(params, user_return_to, current_user, step_url) }

    subject(:execute) { service.execute }

    context 'when onboarding is enabled' do
      before do
        stub_saas_features(onboarding: true)
      end

      it 'places the user into onboarding' do
        expect(execute[:user]).to be_onboarding_in_progress
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_success
      end

      context 'when update is successful' do
        let_it_be_with_reload(:user_with_members) { create(:group_member).user }
        let(:subscription_return) { ::Gitlab::Routing.url_helpers.new_subscriptions_path }
        let(:no_sub_return) { 'some/path' }

        let(:trial_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'trial',
            registration_type: 'trial'
          }
        end

        let(:invite_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'invite',
            registration_type: 'invite'
          }
        end

        let(:subscription_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'subscription',
            registration_type: 'subscription'
          }
        end

        let(:free_registration) do
          {
            step_url: step_url,
            initial_registration_type: 'free',
            registration_type: 'free'
          }
        end

        where(:params, :user_return_to, :current_user, :expected_onboarding_status) do
          { trial: 'true' }  | nil                       | ref(:user_with_members) | ref(:trial_registration)
          { trial: 'true' }  | nil                       | ref(:user)              | ref(:trial_registration)
          { trial: 'false' } | nil                       | ref(:user)              | ref(:free_registration)
          { trial: '' }      | nil                       | ref(:user)              | ref(:free_registration)
          {}                 | nil                       | ref(:user)              | ref(:free_registration)
          {}                 | ref(:subscription_return) | ref(:user)              | ref(:subscription_registration)
          {}                 | ref(:subscription_return) | ref(:user_with_members) | ref(:invite_registration)
          {}                 | nil                       | ref(:user_with_members) | ref(:invite_registration)
          {}                 | nil                       | ref(:user)              | ref(:free_registration)
          {}                 | ref(:no_sub_return)       | ref(:user)              | ref(:free_registration)
        end

        with_them do
          it 'updates onboarding_status_step_url' do
            expect(execute[:user].onboarding_status.symbolize_keys).to eq(expected_onboarding_status)
            expect(execute[:user]).to be_onboarding_in_progress
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_success
          end
        end

        context 'when there is already value in the onboarding_status' do
          before do
            user.update!(onboarding_status_email_opt_in: true)
          end

          it 'merges new data into onboarding_status and does not delete it' do
            expect(execute[:user]).to be_onboarding_in_progress
            expect(execute[:user].onboarding_status.symbolize_keys).to eq(onboarding_status.merge(email_opt_in: true))
          end
        end

        context 'for sanitizing the glm items' do
          let(:params) do
            {
              glm_content: '<div onerror=alert(1)>glm_content</div>',
              glm_source: '<div onerror=alert(1)>glm_content</div>'
            }
          end

          it 'sanitizes', :aggregate_failures do
            expect(execute[:user].onboarding_status_glm_content).to eq('<div>glm_content</div>')
            expect(execute[:user].onboarding_status_glm_source).to eq('<div>glm_content</div>')
          end
        end

        context 'for truncating the glm items' do
          let(:long_string) { 'a' * 300 }
          let(:params) do
            {
              glm_content: long_string,
              glm_source: long_string
            }
          end

          it 'truncates glm items to 255 characters', :aggregate_failures do
            expect(execute[:user].onboarding_status_glm_content).to eq(long_string.truncate(255))
            expect(execute[:user].onboarding_status_glm_source).to eq(long_string.truncate(255))
          end
        end

        context 'for glm items passed as integers' do
          let(:params) do
            {
              glm_content: 12345,
              glm_source: 12345
            }
          end

          it 'converts glm items to strings', :aggregate_failures do
            expect(execute[:user].onboarding_status_glm_content).to eq('12345')
            expect(execute[:user].onboarding_status_glm_source).to eq('12345')
          end
        end

        context 'when user_return_to points at new_subscriptions_path with deployment_type=self_managed' do
          let(:user_return_to) do
            ::Gitlab::Routing.url_helpers.new_subscriptions_path(
              plan_id: 'abc123', deployment_type: 'self_managed', auto_submit_sso: 'true'
            )
          end

          it 'sets subscription_sm registration type and skips onboarding progress', :aggregate_failures do
            result = execute

            expect(result[:user].onboarding_status_registration_type).to eq('subscription_sm')
            expect(result[:user].onboarding_status_initial_registration_type).to eq('subscription_sm')
            expect(result[:user]).not_to be_onboarding_in_progress
            expect(result[:user].onboarding_status_step_url).to be_nil
          end
        end

        context 'when user_return_to points at new_subscriptions_path without deployment_type=self_managed' do
          let(:user_return_to) { ::Gitlab::Routing.url_helpers.new_subscriptions_path(plan_id: 'abc123') }

          it 'resolves as subscription, not subscription_sm' do
            expect(execute[:user].onboarding_status_registration_type).to eq('subscription')
          end
        end
      end

      context 'when update is not successful due to systemic failure' do
        before do
          allow(current_user).to receive(:update).and_return(false)
        end

        it 'does not update the onboarding_status_step_url' do
          expect(execute[:user]).not_to be_onboarding_in_progress
          expect(execute).to be_a(ServiceResponse)
          expect(execute).to be_error
          expect(execute[:user].onboarding_status).to eq({})
        end
      end

      context 'with enterprise user concerns', :saas do
        context 'when the user is an enterprise user' do
          let_it_be(:user) { create(:enterprise_user) }

          it 'does not enter the user into onboarding' do
            expect(execute[:user]).not_to be_onboarding_in_progress
            expect(execute).to be_a(ServiceResponse)
            expect(execute).to be_error
          end
        end

        context 'when the user qualifies to be an enterprise user' do
          let_it_be(:group) { create(:group) }
          let_it_be(:project) { create(:project, group: group) }
          let_it_be_with_reload(:pages_domain) { create(:pages_domain, project: project) }
          let_it_be_with_reload(:user) { create(:user, email: "example@#{pages_domain.domain}") }

          before do
            stub_licensed_features(domain_verification: true)
          end

          context 'with a verified domain' do
            it 'does not enter the user into onboarding' do
              expect(execute[:user]).not_to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_error
            end
          end

          context 'with non verified domain' do
            before do
              pages_domain.update!(verified_at: nil)
            end

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end
          end

          context 'when pages domain is on a personal project' do
            before do
              pages_domain.update!(project: create(:project))
            end

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end
          end

          context 'when user is not human' do
            before do
              user.update!(user_type: :alert_bot)
            end

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end
          end

          context 'when enterprise group is not eligible to be owner of the email' do
            before do
              allow(::Gitlab).to receive(:com?).and_return(false)
            end

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end
          end

          context 'when user is created before the eligibility date' do
            before_all do
              user.update!(created_at: Date.new(2021, 2, 1) - 1.second)
            end

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end

            context 'and they have saml tied to group' do
              before_all do
                saml_provider = create(:saml_provider, group: group)
                create(:group_saml_identity, saml_provider: saml_provider, user: user)
              end

              it 'does not enter the user into onboarding' do
                expect(execute[:user]).not_to be_onboarding_in_progress
                expect(execute).to be_a(ServiceResponse)
                expect(execute).to be_error
              end
            end

            context 'and they have scim identity tied to group' do
              before_all do
                create(:group_scim_identity, group: group, user: user)
              end

              it 'does not enter the user into onboarding' do
                expect(execute[:user]).not_to be_onboarding_in_progress
                expect(execute).to be_a(ServiceResponse)
                expect(execute).to be_error
              end
            end

            context 'and were provisioned by the verified enterprise group' do
              before_all do
                user.update!(provisioned_by_group: group)
              end

              it 'does not enter the user into onboarding' do
                expect(execute[:user]).not_to be_onboarding_in_progress
                expect(execute).to be_a(ServiceResponse)
                expect(execute).to be_error
              end
            end

            context 'and is subscription eligible' do
              before_all do
                group.add_developer(user)
                create(:gitlab_subscription, :ultimate, namespace: group)
              end

              it 'does not enter the user into onboarding' do
                expect(execute[:user]).not_to be_onboarding_in_progress
                expect(execute).to be_a(ServiceResponse)
                expect(execute).to be_error
              end
            end
          end

          context 'when user is a UAT test account with enterprise email' do
            let(:pages_domain) { create(:pages_domain, project: project, domain: 'gitlab.com') }
            let(:user) { create(:user, email: "example+uat@#{pages_domain.domain}") }

            it 'places the user into onboarding' do
              expect(execute[:user]).to be_onboarding_in_progress
              expect(execute).to be_a(ServiceResponse)
              expect(execute).to be_success
            end
          end
        end
      end
    end

    context 'when onboarding is not enabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it 'does not update onboarding_in_progress' do
        expect(execute[:user]).not_to be_onboarding_in_progress
        expect(execute).to be_a(ServiceResponse)
        expect(execute).to be_error
        expect(execute[:user].onboarding_status).to eq({})
      end
    end
  end
end
