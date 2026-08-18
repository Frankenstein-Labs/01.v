# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::ConfigurationController, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let_it_be(:maintainer) { create(:user, maintainer_of: group) }
  let_it_be(:reporter) { create(:user, reporter_of: group) }

  describe 'GET #show', :aggregate_failures do
    subject(:request) { get group_security_configuration_path(group) }

    context 'with authorized user' do
      before do
        sign_in(maintainer)
      end

      context 'when attributes feature is available' do
        before do
          stub_licensed_features(security_attributes: true)
        end

        it 'returns 200 response' do
          request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when scan profiles feature is available' do
        before do
          stub_licensed_features(security_scan_profiles: true)
        end

        it 'returns 200 response' do
          request

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'with unauthorized user' do
      before do
        sign_in(reporter)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when neither feature is available' do
      before do
        sign_in(maintainer)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
