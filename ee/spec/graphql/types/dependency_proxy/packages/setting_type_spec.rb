# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['DependencyProxyPackagesSetting'], feature_category: :package_registry do
  it 'includes dependency proxy for packages fields' do
    expected_fields = %w[
      enabled
      maven_external_registry_url
      maven_external_registry_username
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  it { expect(described_class).to require_graphql_authorizations(:admin_dependency_proxy_packages_settings) }

  it { expect(described_class.graphql_name).to eq('DependencyProxyPackagesSetting') }

  it { expect(described_class.description).to eq('Project-level Dependency Proxy for packages settings') }
end
