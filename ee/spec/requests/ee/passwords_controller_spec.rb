# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PasswordsController, type: :request, feature_category: :system_access do
  describe 'POST #complexity' do
    subject(:password_complexity_validation) { post users_password_complexity_path, params: params }

    context 'when the password is weak' do
      let(:params) { { user: { first_name: 'aaaa', password: 'aaaaaaaa' } } }

      it 'returns JSON response' do
        password_complexity_validation

        expect(json_response).to eq('common' => true, 'user_info' => true)
      end
    end

    context 'when the password is NOT weak' do
      let(:params) { { user: { first_name: 'aaaa', password: 'eeeeeeee' } } }

      it 'returns JSON response' do
        password_complexity_validation

        expect(json_response).to eq('common' => false, 'user_info' => false)
      end
    end

    context 'when user parameter is missing' do
      let(:params) { {} }

      it 'raises an error' do
        expect { password_complexity_validation }.to raise_error(ActionController::ParameterMissing)
      end
    end
  end
end
