# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting dependency proxy for packages settings for a project', feature_category: :package_registry do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project) }

  let(:setting_fields) do
    <<-GQL
      enabled
      mavenExternalRegistryUrl
      mavenExternalRegistryUsername
    GQL
  end

  let(:fields) do
    <<-GQL
      #{query_graphql_field('dependency_proxy_packages_setting', {}, setting_fields)}
    GQL
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      fields
    )
  end

  let(:dependency_proxy_packages_setting_response) { graphql_data.dig('project', 'dependencyProxyPackagesSetting') }

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(dependency_proxy_for_packages: true)
  end

  subject { post_graphql(query, current_user: user, variables: {}) }

  shared_examples 'querying the dependency proxy for packages setting' do
    it_behaves_like 'a working graphql query' do
      before do
        subject
      end
    end

    context 'with different permissions' do
      where(:visibility, :role, :access_granted) do
        :public   | :developer  | false
        :public   | :maintainer | true
        :internal | :developer  | false
        :internal | :maintainer | true
        :private  | :developer  | false
        :private  | :maintainer | true
      end

      with_them do
        before do
          project.update_column(:visibility_level, Gitlab::VisibilityLevel.const_get(visibility.to_s.upcase, false))
          project.add_member(user, role)
        end

        it 'returns the proper response' do
          subject

          if access_granted
            expect(dependency_proxy_packages_setting_response).to eq(to_hash(project.dependency_proxy_packages_setting))
          else
            expect(dependency_proxy_packages_setting_response).to be_blank
          end
        end

        def to_hash(setting)
          result = {}
          %w[enabled maven_external_registry_url maven_external_registry_username].each do |field|
            result[field.camelize(:lower)] = setting.public_send(field)
          end
          result
        end
      end
    end
  end

  context 'without the settings model created' do
    it_behaves_like 'querying the dependency proxy for packages setting'
  end

  context 'with the settings model created' do
    before do
      create(:dependency_proxy_packages_setting, project: project)
    end

    it_behaves_like 'querying the dependency proxy for packages setting'
  end

  context 'with a maintainer' do
    before_all do
      project.add_maintainer(user)
    end

    shared_examples 'returning a blank response' do
      it 'returns a blank response' do
        subject

        expect(dependency_proxy_packages_setting_response).to be_blank
      end
    end

    %i[dependency_proxy packages].each do |feature|
      context "with #{feature} disabled in the config" do
        before do
          stub_config(feature => { enabled: false })
        end

        it_behaves_like 'returning a blank response'
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

      it_behaves_like 'returning a blank response'
    end

    context 'with licensed dependency proxy for packages disabled' do
      before do
        stub_licensed_features(dependency_proxy_for_packages: false)
      end

      it_behaves_like 'returning a blank response'
    end
  end
end
