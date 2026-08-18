# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating the dependency proxy packages settings', :aggregate_failures, feature_category: :package_registry do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }

  let(:params) do
    {
      project_path: project.full_path,
      enabled: true,
      maven_external_registry_url: 'https://test.dev',
      maven_external_registry_username: 'test',
      maven_external_registry_password: 'password'
    }
  end

  let(:mutation) do
    graphql_mutation(:update_dependency_proxy_packages_settings, params) do
      <<~QL
        dependencyProxyPackagesSetting {
          enabled
          mavenExternalRegistryUrl
          mavenExternalRegistryUsername
        }
        errors
      QL
    end
  end

  let(:mutation_response) { graphql_mutation_response(:update_dependency_proxy_packages_settings) }
  let(:settings_response) { mutation_response['dependencyProxyPackagesSetting'] }

  describe 'post graphql mutation' do
    subject { post_graphql_mutation(mutation, current_user: user) }

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(dependency_proxy_for_packages: true)
    end

    where(:role, :result, :existing_settings) do
      :anonymous  | :denied  | true
      :anonymous  | :denied  | false
      :developer  | :denied  | true
      :developer  | :denied  | false
      :maintainer | :success | true
      :maintainer | :success | false
    end

    with_them do
      context "with #{params[:existing_settings] ? 'existing' : 'non existing'} settings" do
        before do
          create(:dependency_proxy_packages_setting, project: project) if existing_settings
        end

        it 'returns the correct result' do
          project.send("add_#{role}", user) unless role == :anonymous

          if result == :success
            expect { subject }.to change { ::DependencyProxy::Packages::Setting.count }.by(existing_settings ? 0 : 1)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty

            expect(settings_response['enabled']).to eq(params[:enabled])
            expect(settings_response['mavenExternalRegistryUrl']).to eq(params[:maven_external_registry_url])
            expect(settings_response['mavenExternalRegistryUsername'])
              .to eq(params[:maven_external_registry_username])

            created_settings = project.dependency_proxy_packages_setting.reload
            expect(created_settings.enabled).to eq(params[:enabled])
            expect(created_settings.maven_external_registry_url).to eq(params[:maven_external_registry_url])
            expect(created_settings.maven_external_registry_username).to eq(params[:maven_external_registry_username])
            expect(created_settings.maven_external_registry_password).to eq(params[:maven_external_registry_password])
          else
            expect { subject }.to not_change { ::DependencyProxy::Packages::Setting.count }
            expect_graphql_errors_to_include(::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
          end
        end
      end

      context 'with a non existing project path' do
        let(:params) { super().merge!(project_path: 'non_existing/project/path') }

        it 'returns the resource access error' do
          project.add_maintainer(user)

          expect { subject }.to not_change { ::DependencyProxy::Packages::Setting.count }
          expect_graphql_errors_to_include(::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
        end
      end
    end

    context 'without permission' do
      it 'returns no response' do
        subject

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response).to be_nil
      end
    end

    context 'with a maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_dependency_proxy_packages_setting do
        let(:boundary_object) { project }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      shared_examples 'returning a graphql error' do |message|
        it 'does not create any setting' do
          expect { subject }.to not_change { ::DependencyProxy::Packages::Setting.count }
          expect_graphql_errors_to_include(message)
        end
      end

      context 'with blank values' do
        let(:params) { super().merge(maven_external_registry_username: nil, maven_external_registry_password: '') }

        it 'nullifies blank values' do
          subject

          expect(response).to have_gitlab_http_status(:success)
          expect(settings_response['mavenExternalRegistryUsername']).to be_nil
          expect(settings_response['mavenExternalRegistryPassword']).to be_nil

          created_settings = project.dependency_proxy_packages_setting.reload
          expect(created_settings.maven_external_registry_username).to be_nil
          expect(created_settings.maven_external_registry_password).to be_nil
        end
      end

      %i[packages dependency_proxy].each do |feature|
        context "with config #{feature} disabled" do
          before do
            stub_config(feature => { enabled: false })
          end

          it_behaves_like 'returning a graphql error',
            ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR
        end
      end

      context 'with packages feature disabled in the project' do
        before do
          # package registry project settings lives in two locations:
          # project.project_feature.package_registry_access_level and project.packages_enabled.
          # Both are synced with callbacks. Here for test setup, we need to make sure that
          # both are properly set.
          project.update!(package_registry_access_level: 'disabled', packages_enabled: false)
        end

        it_behaves_like 'returning a graphql error',
          ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR
      end

      context 'with licensed dependency proxy for packages disabled' do
        before do
          stub_licensed_features(dependency_proxy_for_packages: false)
        end

        it_behaves_like 'returning a graphql error',
          ::Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR
      end
    end
  end
end
