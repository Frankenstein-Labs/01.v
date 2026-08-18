# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::UsersController, feature_category: :user_management do
  include AdminModeHelper

  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:user) { create(:user) }

  context 'as an instance admin', :enable_admin_mode do
    before do
      sign_in(admin)
    end

    describe 'GET card_match' do
      context 'when not SaaS' do
        it 'responds with 404' do
          send_request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when SaaS', :saas do
        context 'when user has no credit card validation' do
          it 'redirects back to #show' do
            send_request

            expect(response).to redirect_to(admin_user_path(user))
          end
        end

        context 'when user has credit card validation' do
          let_it_be(:credit_card_validation) { create(:credit_card_validation, user: user) }
          let_it_be(:card_details) do
            credit_card_validation.attributes.slice(:expiration_date, :last_digits, :holder_name)
          end

          let_it_be(:match) { create(:credit_card_validation, card_details) }

          it 'displays its own and matching card details', :aggregate_failures do
            send_request

            expect(response).to have_gitlab_http_status(:ok)

            expect(response.body).to include(match.user.id.to_s)
            expect(response.body).to include(match.user.username)
            expect(response.body).to include(match.user.name)
            expect(response.body).to include(match.credit_card_validated_at.to_fs(:medium))
            expect(response.body).to include(match.user.created_at.to_fs(:medium))
          end
        end
      end

      def send_request
        get card_match_admin_user_path(user)
      end
    end

    describe 'GET #index' do
      it 'eager loads required associations' do
        get admin_users_path

        expect(assigns(:users).first.association(:user_highest_role)).to be_loaded
        expect(assigns(:users).first.association(:elevated_members)).to be_loaded
        expect(assigns(:users).first.association(:member_role)).to be_loaded
      end
    end

    describe 'PATCH #update' do
      let(:new_email) { 'new-email@example.com' }
      let(:user_attrs) { { email: new_email } }

      subject(:request) { patch admin_user_path(user), params: { user: user_attrs } }

      context 'when user is an enterprise user' do
        let(:user) { create(:enterprise_user) }

        context "when new email is not owned by the user's enterprise group" do
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/412762
          it 'allows change user email', :aggregate_failures do
            expect { request }.to change { user.reload.email }.from(user.email).to(new_email)

            expect(response).to redirect_to(admin_user_path(user))
            expect(flash[:notice]).to eq('User was successfully updated.')
          end
        end
      end

      describe 'custom admin role assignment' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when the user has an assigned role' do
          let_it_be(:existing_role) { create(:admin_member_role, user: user).member_role }

          context 'and admin_role_id is not present' do
            it 'does not unassign the user\'s existing role' do
              expect { request }.not_to change { user.reload.member_role }.from(existing_role)
            end

            context 'when user is an admin' do
              let_it_be(:user) { create(:admin) }
              let_it_be(:existing_role) { create(:admin_member_role, user: user).member_role }

              it 'unassigns the user\'s existing role' do
                expect { request }.to change { user.reload.member_role }.from(existing_role).to(nil)
              end
            end
          end

          context 'when admin_role_id is present' do
            context 'and matches a custom admin role' do
              let_it_be(:new_role) { create(:member_role, :admin) }
              let(:user_attrs) { super().merge(admin_role_id: new_role.id) }

              it 'updates the user\'s assigned role to the new role' do
                expect { request }.to change { user.reload.member_role }.from(existing_role).to(new_role)
              end

              context 'and assignment fails' do
                let(:service_error) { 'Failure reason' }

                it 'redirects with an alert flash' do
                  expect_next_instance_of(::Users::MemberRoles::AssignService) do |service|
                    error = ServiceResponse.error(message: service_error)
                    expect(service).to receive(:execute).and_return(error)
                  end

                  request

                  expect(response).to redirect_to(admin_user_path(user))
                  expect(flash[:alert])
                    .to eq("Failed to assign custom admin role. Try again or select a different role.")
                end
              end

              shared_examples 'does not execute assignment service' do
                specify do
                  expect(::Users::MemberRoles::AssignService).not_to receive(:new)

                  request
                end
              end

              context 'when feature is not available' do
                before do
                  stub_licensed_features(custom_roles: false)
                end

                it_behaves_like 'does not execute assignment service'
              end
            end

            context 'and is nil' do
              let(:user_attrs) { super().merge(admin_role_id: nil) }

              it 'unassigns the user\'s existing role' do
                expect { request }.to change { user.reload.member_role }.from(existing_role).to(nil)
              end
            end
          end
        end

        context 'when the user has no assigned role' do
          context 'when admin_role_id is present' do
            context 'and matches a custom admin role' do
              let_it_be(:role) { create(:member_role, :admin) }
              let(:user_attrs) { super().merge(admin_role_id: role.id) }

              it 'assigns the role to the user' do
                expect { request }.to change { user.reload.member_role }.from(nil).to(role)
              end
            end

            context 'and does not match a custom admin role' do
              let(:user_attrs) { super().merge(admin_role_id: non_existing_record_id) }

              it 'does not assign any role to the user' do
                expect { request }.not_to change { user.user_member_role }
              end
            end
          end
        end
      end
    end

    describe 'PUT #unlock' do
      before do
        user.lock_access!
      end

      subject(:request) { put unlock_admin_user_path(user) }

      it 'logs a user_access_unlock audit event with author set to the current user' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'user_access_unlocked',
            author: admin
          )
        ).and_call_original

        expect { request }.to change { user.reload.access_locked? }.from(true).to(false)
      end
    end

    describe 'POST #create', :with_current_organization do
      let(:user_attrs) { attributes_for(:user).slice(:name, :username, :email) }

      subject(:request) { post admin_users_path, params: { user: user_attrs } }

      def created_user
        User.find_by_email(user_attrs[:email])
      end

      describe 'custom admin role assignment' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        context 'when admin_role_id is present' do
          context 'and matches a custom admin role' do
            let_it_be(:role) { create(:member_role, :admin) }
            let(:user_attrs) { super().merge(admin_role_id: role.id) }

            it 'assigns the role to the user' do
              request

              expect(created_user.member_role).to eq(role)
            end

            context 'and assignment fails' do
              let(:service_error) { 'Failure reason' }

              it 'redirects with an alert flash' do
                expect_next_instance_of(::Users::MemberRoles::AssignService) do |service|
                  error = ServiceResponse.error(message: service_error)
                  expect(service).to receive(:execute).and_return(error)
                end

                request

                expect(response).to redirect_to(admin_user_path(created_user))
                expect(flash[:alert]).to eq("Failed to assign custom admin role. Try again or select a different role.")
              end
            end

            shared_examples 'does not execute assignment service' do
              specify do
                expect(::Users::MemberRoles::AssignService).not_to receive(:new)

                request
              end
            end

            context 'when feature is not available' do
              before do
                stub_licensed_features(custom_roles: false)
              end

              it_behaves_like 'does not execute assignment service'
            end
          end

          context 'and does not match a custom admin role' do
            let(:user_attrs) { super().merge(admin_role_id: non_existing_record_id) }

            it 'does not assign any role to the user' do
              request

              expect(created_user.user_member_role).to be_nil
            end
          end
        end
      end
    end
  end

  context 'as an organization admin' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:organization_owner) { create(:user, :organization_owner, organization: organization) }

    before do
      sign_in(organization_owner)
    end

    it 'denies access to #index' do
      get admin_users_path

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'denies access to #show' do
      get admin_user_path(user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when the X-GitLab-Organization-ID header is set to the owned organization' do
      let(:headers) { { Gitlab::Current::Organization::HTTP_HEADER => organization.id.to_s } }

      it 'does not set an organization context and denies access to #index' do
        get admin_users_path, headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end

      it 'does not set an organization context and denies access to #show' do
        get admin_user_path(user), headers: headers

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
