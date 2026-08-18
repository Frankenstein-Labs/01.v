# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyProxy::Packages::Settings::UpdateService, :aggregate_failures, feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:setting) { project.dependency_proxy_packages_setting }
  let(:service) { described_class.new(setting: setting, current_user: user, params: params) }
  let(:params) do
    {
      enabled: true,
      maven_external_registry_url: 'http://test.dev',
      maven_external_registry_username: 'test',
      maven_external_registry_password: 'password'
    }
  end

  describe '#execute' do
    subject(:response) { service.execute }

    shared_examples 'returning an error response with' do |message|
      it 'does not create the setting object' do
        expect { response }.not_to change { DependencyProxy::Packages::Setting.count }

        expect(response).to be_a(ServiceResponse)
        expect(response).to be_error
        expect(response.message).to eq(message)
      end
    end

    before do
      stub_config(dependency_proxy: { enabled: true })
      stub_licensed_features(dependency_proxy_for_packages: true)
    end

    context 'with a maintainer' do
      before_all do
        project.add_maintainer(user)
      end

      context 'with valid params' do
        it 'creates the setting object' do
          expect { response }.to change { DependencyProxy::Packages::Setting.count }.by(1)

          expect(setting.enabled).to eq(params[:enabled])
          expect(setting.maven_external_registry_url).to eq(params[:maven_external_registry_url])
          expect(setting.maven_external_registry_username).to eq(params[:maven_external_registry_username])
          expect(setting.maven_external_registry_password).to eq(params[:maven_external_registry_password])

          expect(response).to be_a(ServiceResponse)
          expect(response).to be_success
          expect(response.payload[:dependency_proxy_packages_setting]).to eq(setting)
        end

        context 'with existing setting' do
          let_it_be(:settings) { create(:dependency_proxy_packages_setting, project: project) }

          it 'updates the existing setting object' do
            expect { response }.not_to change { DependencyProxy::Packages::Setting.count }

            expect(setting.enabled).to eq(params[:enabled])
            expect(setting.maven_external_registry_url).to eq(params[:maven_external_registry_url])
            expect(setting.maven_external_registry_username).to eq(params[:maven_external_registry_username])
            expect(setting.maven_external_registry_password).to eq(params[:maven_external_registry_password])

            expect(response).to be_a(ServiceResponse)
            expect(response).to be_success
            expect(response.payload[:dependency_proxy_packages_setting]).to eq(setting.reload)
          end
        end

        %i[packages dependency_proxy].each do |feature|
          context "with #{feature} disabled in the config" do
            before do
              stub_config(feature => { enabled: false })
            end

            it_behaves_like 'returning an error response with', 'Access Denied'
          end
        end

        context 'with packages feature disabled in the project' do
          before do
            # package registry project setting lives in two locations:
            # project.project_feature.package_registry_access_level and project.packages_enabled.
            # Both are synced with callbacks. Here for test setup, we need to make sure that
            # both are properly set.
            project.update!(package_registry_access_level: 'disabled', packages_enabled: false)
          end

          it_behaves_like 'returning an error response with', 'Access Denied'
        end

        context 'with licensed dependency proxy for packages disabled' do
          before do
            stub_licensed_features(dependency_proxy_for_packages: false)
          end

          it_behaves_like 'returning an error response with', 'Access Denied'
        end
      end

      context 'with invalid params' do
        let(:params) do
          {
            enabled: true,
            maven_external_registry_url: 'http://test.dev',
            maven_external_registry_username: 'test'
          }
        end

        it_behaves_like 'returning an error response with', "Maven external registry password can't be blank"
      end
    end

    context 'for user permissions' do
      where(:role, :result) do
        :anonymous  | :access_denied
        :developer  | :access_denied
        :maintainer | :success
      end

      with_them do
        it 'returns the correct response' do
          project.send("add_#{role}", user) unless role == :anonymous

          if result == :success
            expect(response).to be_success
          else
            expect(response).to be_error
            expect(response.message).to eq(result.to_s.titleize)
          end
        end
      end
    end
  end
end
