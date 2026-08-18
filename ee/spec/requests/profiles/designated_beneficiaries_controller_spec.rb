# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Profile designated beneficiaries', feature_category: :user_profile do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    sign_in(user)
  end

  shared_examples 'handles missing designated beneficiary gracefully' do |http_method|
    it 'redirects with notice message' do
      send(http_method, profile_designated_beneficiary_path(non_existing_record_id))

      expect(response).to redirect_to(profile_account_path)
      expect(flash[:notice]).to eq('Designated account beneficiary already deleted.')
    end
  end

  describe 'POST /profile/account/designated_beneficiaries' do
    context 'with valid params' do
      context 'when creating a manager type' do
        let(:params) do
          {
            users_designated_beneficiary: {
              name: 'John Doe',
              email: 'john@example.com',
              type: 'manager'
            }
          }
        end

        it 'creates a manager and shows proper success message' do
          expect do
            post profile_designated_beneficiaries_path, params: params
          end.to change { user.designated_beneficiaries.count }.by(1)

          manager = user.designated_account_manager
          expect(manager.name).to eq('John Doe')
          expect(manager.email).to eq('john@example.com')

          # rubocop:disable Layout/LineLength -- To avoid multi-line split
          expected_msg = 'Account manager added successfully. They can <a target="_blank" rel="noopener noreferrer" href="https://about.gitlab.com/support/#contact-support">contact GitLab</a> to gain access to your account in the event of your incapacitation.'
          # rubocop:enable Layout/LineLength
          expect(flash[:success]).to eq(expected_msg)
        end
      end

      context 'when creating a successor type' do
        let(:params) do
          {
            users_designated_beneficiary: {
              name: 'Jane Doe',
              email: 'jane@example.com',
              relationship: 'Sister',
              type: 'successor'
            }
          }
        end

        it 'creates a successor and shows proper success message' do
          expect do
            post profile_designated_beneficiaries_path, params: params
          end.to change { user.designated_beneficiaries.count }.by(1)

          successor = user.designated_account_successor
          expect(successor.name).to eq('Jane Doe')
          expect(successor.email).to eq('jane@example.com')
          expect(successor.relationship).to eq('Sister')

          # rubocop:disable Layout/LineLength -- To avoid multi-line split
          expected_msg = 'Account successor added successfully. They can <a target="_blank" rel="noopener noreferrer" href="https://about.gitlab.com/support/#contact-support">contact GitLab</a> to gain access to your account in the event of your death.' # -- For simplicity
          # rubocop:enable Layout/LineLength
          expect(flash[:success]).to eq(expected_msg)
        end
      end
    end

    context 'with invalid params' do
      let(:params) do
        {
          users_designated_beneficiary: {
            name: '',
            email: 'invalid-email',
            type: 'manager'
          }
        }
      end

      it 'does not create a designated beneficiary and shows error' do
        expect do
          post profile_designated_beneficiaries_path, params: params
        end.not_to change { user.designated_beneficiaries.count }

        expect(response).to redirect_to(profile_account_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH /profile/account/designated_beneficiaries/:id' do
    context 'for manager' do
      let(:manager) { create(:designated_beneficiary, :manager, user: user, name: "Name") }

      let(:params) do
        {
          users_designated_beneficiary: {
            name: 'Updated Name',
            email: 'new_email@example.com'
          }
        }
      end

      it 'updates attrs and shows proper success message' do
        patch profile_designated_beneficiary_path(manager), params: params

        expect(manager.reload.name).to eq('Updated Name')
        expect(manager.reload.email).to eq('new_email@example.com')

        # rubocop:disable Layout/LineLength -- To avoid multi-line split
        expected_msg = 'Account manager updated successfully. They can <a target="_blank" rel="noopener noreferrer" href="https://about.gitlab.com/support/#contact-support">contact GitLab</a> to gain access to your account in the event of your incapacitation.' # -- For simplicity
        # rubocop:enable Layout/LineLength
        expect(flash[:success]).to eq(expected_msg)
      end

      context 'with invalid params' do
        it 'does not update and shows error' do
          params[:users_designated_beneficiary] = { name: '' }

          patch profile_designated_beneficiary_path(manager), params: params

          expect(manager.reload.name).to eq("Name")
          expect(flash[:alert]).to eq("Full name is required")
        end
      end

      context 'when attempting to change type' do
        it 'does not allow changing from manager to successor' do
          params[:users_designated_beneficiary] = {
            name: 'Updated Name',
            email: 'new_email@example.com',
            type: 'successor'
          }

          patch profile_designated_beneficiary_path(manager), params: params

          expect(manager.reload.type).to eq('manager')
          expect(manager.reload.name).to eq('Updated Name') # Other fields should still update
          expect(manager.reload.email).to eq('new_email@example.com')
        end
      end
    end

    context 'for successor' do
      let(:successor) { create(:designated_beneficiary, :successor, user: user, name: "Name") }

      let(:params) do
        {
          users_designated_beneficiary: {
            name: 'Updated Name',
            email: 'new_email@example.com',
            relationship: 'Updated Relationship'
          }
        }
      end

      it 'updates attrs and shows proper success message' do
        patch profile_designated_beneficiary_path(successor), params: params

        expect(successor.reload.name).to eq('Updated Name')
        expect(successor.reload.email).to eq('new_email@example.com')
        expect(successor.reload.relationship).to eq('Updated Relationship')

        # rubocop:disable Layout/LineLength -- To avoid multi-line split
        expected_msg = 'Account successor updated successfully. They can <a target="_blank" rel="noopener noreferrer" href="https://about.gitlab.com/support/#contact-support">contact GitLab</a> to gain access to your account in the event of your death.' # -- For simplicity
        # rubocop:enable Layout/LineLength
        expect(flash[:success]).to eq(expected_msg)
      end

      context 'with invalid params' do
        it 'does not update and shows error' do
          params[:users_designated_beneficiary] = { name: '' }

          patch profile_designated_beneficiary_path(successor), params: params

          expect(successor.reload.name).to eq("Name")
          expect(flash[:alert]).to eq("Full name is required")
        end
      end

      context 'when attempting to change type' do
        it 'does not allow changing from successor to manager' do
          params[:users_designated_beneficiary] = {
            name: 'Updated Name',
            email: 'new_email@example.com',
            relationship: 'Updated Relationship',
            type: 'manager'
          }

          patch profile_designated_beneficiary_path(successor), params: params

          expect(successor.reload.type).to eq('successor')
          expect(successor.reload.name).to eq('Updated Name') # Other fields should still update
          expect(successor.reload.email).to eq('new_email@example.com')
          expect(successor.reload.relationship).to eq('Updated Relationship')
        end
      end
    end

    context 'when trying to update another user\'s designated beneficiary' do
      let(:other_designated_beneficiary) { create(:designated_beneficiary, :manager, user: other_user, name: "Name") }

      let(:params) do
        {
          users_designated_beneficiary: {
            name: 'Updated Name'
          }
        }
      end

      it 'does not allow' do
        patch profile_designated_beneficiary_path(other_designated_beneficiary), params: params

        expect(response).to redirect_to(profile_account_path)
        expect(response).to have_gitlab_http_status(:see_other)
        expect(flash[:notice]).to eq('Designated account beneficiary already deleted.')
        expect(other_designated_beneficiary.reload.name).to eq("Name")
      end
    end

    context 'when designated beneficiary does not exist' do
      include_examples 'handles missing designated beneficiary gracefully', :patch
    end
  end

  describe 'DELETE /profile/account/designated_beneficiaries/:id' do
    let!(:designated_beneficiary) { create(:designated_beneficiary, :manager, user: user) }

    it 'destroys the designated beneficiary' do
      expect do
        delete profile_designated_beneficiary_path(designated_beneficiary)
      end.to change { user.designated_beneficiaries.count }.by(-1)

      expect(response).to redirect_to(profile_account_path)
      expect(response).to have_gitlab_http_status(:see_other)
      expect(flash[:notice]).to eq('Account manager deleted successfully.')
    end

    context 'with successor type' do
      let!(:designated_beneficiary) { create(:designated_beneficiary, :successor, user: user) }

      it 'shows correct type in deletion message' do
        delete profile_designated_beneficiary_path(designated_beneficiary)

        expect(flash[:notice]).to eq('Account successor deleted successfully.')
      end
    end

    context 'when trying to delete another user\'s designated beneficiary' do
      let(:other_designated_beneficiary) { create(:designated_beneficiary, :manager, user: other_user) }

      it 'does not allow' do
        delete profile_designated_beneficiary_path(other_designated_beneficiary)

        expect(response).to redirect_to(profile_account_path)
        expect(response).to have_gitlab_http_status(:see_other)
        expect(flash[:notice]).to eq('Designated account beneficiary already deleted.')
        expect(other_designated_beneficiary.reload.persisted?).to be(true)
      end
    end

    context 'when designated beneficiary does not exist' do
      include_examples 'handles missing designated beneficiary gracefully', :delete
    end

    # We don't expect to hit that code path, but we cover it
    context 'when destroy fails' do
      before do
        allow_next_found_instance_of(Users::DesignatedBeneficiary) do |instance|
          allow(instance).to receive(:destroy).and_return(false)
        end
      end

      it 'shows failure message' do
        delete profile_designated_beneficiary_path(designated_beneficiary)

        expect(response).to redirect_to(profile_account_path)
        expect(flash[:alert]).to eq('Failed to delete designated account beneficiary.')
      end
    end
  end
end
