# frozen_string_literal: true

require('spec_helper')

RSpec.describe UserSettings::ProfilesController, :request_store, feature_category: :user_profile do
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  describe 'PUT update', feature_category: :user_profile do
    context 'on updating name' do
      subject(:perform_update) { put :update, params: { user: { name: 'New Name' } } }

      shared_examples_for 'a user can update their name' do
        before do
          sign_in(current_user)
        end

        it 'updates their name' do
          perform_update

          expect(response).to have_gitlab_http_status(:found)
          expect(current_user.reload.name).to eq('New Name')
        end
      end

      context 'when `disable_name_update_for_users` feature is available' do
        before do
          stub_licensed_features(disable_name_update_for_users: true)
        end

        context 'when the ability to update thier name is not disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: false)
          end

          it_behaves_like 'a user can update their name' do
            let(:current_user) { user }
          end

          it_behaves_like 'a user can update their name' do
            let(:current_user) { admin }
          end
        end

        context 'when the ability to update their name is disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: true)
          end

          context 'as a regular user' do
            before do
              sign_in(user)
            end

            it 'does not update their name' do
              perform_update

              expect(response).to have_gitlab_http_status(:found)
              expect(user.reload.name).not_to eq('New Name')
            end
          end

          context 'as an admin in admin mode', :enable_admin_mode do
            it_behaves_like 'a user can update their name' do
              let(:current_user) { admin }
            end
          end
        end
      end

      context 'when `disable_name_update_for_users` feature is not available' do
        before do
          stub_licensed_features(disable_name_update_for_users: false)
        end

        it_behaves_like 'a user can update their name' do
          let(:current_user) { user }
        end

        it_behaves_like 'a user can update their name' do
          let(:current_user) { admin }
        end
      end
    end
  end

  context 'on updating public profile to private' do
    subject(:perform_update) { put :update, params: { user: { private_profile: true } } }

    shared_examples_for 'a user can make their profile private' do
      before do
        sign_in(current_user)
      end

      it 'updates their profile to private' do
        perform_update

        expect(response).to have_gitlab_http_status(:found)
        expect(current_user.reload.private_profile).to be true
      end
    end

    shared_examples_for 'a user cannot make their profile private' do
      before do
        sign_in(current_user)
      end

      it 'does not update their profile to private' do
        perform_update
        expect(current_user.reload.private_profile).not_to be true
      end
    end

    context 'when `disable_private_profiles` feature is available' do
      before do
        stub_licensed_features(disable_private_profiles: true)
      end

      context 'when the ability to make their profile private is disabled' do
        before do
          stub_application_setting(make_profile_private: false)
        end

        context 'as a regular user' do
          it_behaves_like 'a user cannot make their profile private' do
            let(:current_user) { user }
          end
        end
      end

      context 'when the ability to make their profile private is not disabled' do
        before do
          stub_application_setting(make_profile_private: true)
        end

        context 'as a regular user' do
          it_behaves_like 'a user can make their profile private' do
            let(:current_user) { user }
          end
        end
      end
    end

    context 'when `disable_private_profiles` feature is not available' do
      before do
        stub_application_setting(make_profile_private: false)
        stub_licensed_features(disable_private_profiles: false)
      end

      it_behaves_like 'a user can make their profile private' do
        let(:current_user) { user }
      end
    end
  end
end
