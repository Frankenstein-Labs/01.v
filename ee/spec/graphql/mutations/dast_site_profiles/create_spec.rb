# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::DastSiteProfiles::Create, feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }

  let(:full_path) { project.full_path }
  let(:profile_name) { SecureRandom.hex }
  let(:target_url) { generate(:url) }
  let(:excluded_urls) { ["#{target_url}/signout"] }

  let_it_be(:request_headers) { 'Authorization: token' }
  let_it_be(:target_type) { 'api' }
  let_it_be(:scan_method) { 'openapi' }
  let_it_be(:scan_file_path) { 'https://www.domain.com/test-api-specification.json' }
  let_it_be(:optional_variables) { [] }

  let(:auth) do
    {
      enabled: true,
      url: "#{target_url}/login",
      username_field: 'session[username]',
      password_field: 'session[password]',
      submit_field: 'css:button[type="submit"]',
      username: generate(:email),
      password: SecureRandom.hex
    }
  end

  let(:dast_site_profile) { DastSiteProfile.find_by(project: project, name: profile_name) }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before do
    stub_licensed_features(security_on_demand_scans: true)
  end

  specify { expect(described_class).to require_graphql_authorizations(:create_on_demand_dast_scan) }

  describe '#resolve' do
    subject(:mutation_response) do
      mutation.resolve(
        full_path: full_path,
        profile_name: profile_name,
        target_url: target_url,
        target_type: target_type,
        excluded_urls: excluded_urls,
        request_headers: request_headers,
        auth: auth,
        scan_method: scan_method,
        scan_file_path: scan_file_path,
        optional_variables: optional_variables
      )
    end

    context 'when on demand scan feature is enabled' do
      context 'when the project does not exist' do
        let(:full_path) { SecureRandom.hex }

        it 'raises an exception' do
          expect { mutation_response }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user can run a dast scan' do
        before_all do
          project.add_developer(current_user)
        end

        it 'creates a dast_site_profile and dast_site_profile_secret_variables', :aggregate_failures do
          dast_site_profile = mutation_response[:id].find

          expect(dast_site_profile).to have_attributes(
            name: profile_name,
            excluded_urls: excluded_urls,
            auth_enabled: auth[:enabled],
            auth_url: auth[:url],
            auth_username_field: auth[:username_field],
            auth_password_field: auth[:password_field],
            auth_submit_field: auth[:submit_field],
            auth_username: auth[:username],
            dast_site: have_attributes(url: target_url),
            target_type: target_type,
            scan_method: scan_method,
            scan_file_path: scan_file_path,
            optional_variables: optional_variables
          )

          password_variable = dast_site_profile.secret_variables.find_by!(key: Dast::SiteProfileSecretVariable::PASSWORD)
          expect(password_variable.value).to eq(Base64.strict_encode64(auth[:password]))

          request_headers_variable = dast_site_profile.secret_variables.find_by!(key: Dast::SiteProfileSecretVariable::REQUEST_HEADERS)
          expect(request_headers_variable.value).to eq(Base64.strict_encode64(request_headers))
        end

        it 'returns the dast_site_profile id' do
          expect(mutation_response[:id]).to eq(dast_site_profile.to_global_id)
        end

        it 'returns the complete dast_site_profile' do
          expect(mutation_response[:dast_site_profile]).to eq(dast_site_profile)
        end

        it 'calls the dast_site_profile creation service' do
          service = double(::AppSec::Dast::SiteProfiles::CreateService)
          result = ServiceResponse.error(message: '')

          service_params = {
            name: profile_name,
            target_url: target_url,
            target_type: target_type,
            excluded_urls: excluded_urls,
            request_headers: request_headers,
            scan_method: scan_method,
            scan_file_path: scan_file_path,
            optional_variables: optional_variables,
            auth_enabled: auth[:enabled],
            auth_url: auth[:url],
            auth_username_field: auth[:username_field],
            auth_password_field: auth[:password_field],
            auth_submit_field: auth[:submit_field],
            auth_username: auth[:username],
            auth_password: auth[:password]
          }

          expect(::AppSec::Dast::SiteProfiles::CreateService).to receive(:new).and_return(service)
          expect(service).to receive(:execute).with(service_params).and_return(result)

          mutation_response
        end

        context 'when the project name already exists' do
          it 'returns an error' do
            mutation_response

            response = mutation.resolve(
              full_path: full_path,
              profile_name: profile_name,
              target_url: target_url
            )

            expect(response[:errors]).to include('Name has already been taken')
          end
        end

        context 'when variable creation fails' do
          it 'returns an error and the dast_site_profile' do
            service = double(AppSec::Dast::SiteProfileSecretVariables::CreateOrUpdateService)
            result = ServiceResponse.error(payload: create(:dast_site_profile), message: 'Oops')

            allow(AppSec::Dast::SiteProfileSecretVariables::CreateOrUpdateService).to receive(:new).and_return(service)
            allow(service).to receive(:execute).and_return(result)

            expect(mutation_response).to include(errors: ['Oops'])
          end
        end
      end
    end
  end
end
