# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Organizations artifact registry routing', :routing, feature_category: :artifact_registry do
  let_it_be(:organization) { build(:organization) }

  specify 'to #index' do
    expect(get("/o/#{organization.path}/-/artifact_registry"))
      .to route_to('organizations/artifact_registry#index', organization_path: organization.path)
  end

  describe 'slug-scoped repositories routes' do
    it 'routes the repositories base path to artifact_registry_repositories#index, capturing the slug' do
      expect(get("/o/#{organization.path}/-/artifact_registry/any-slug/repositories"))
        .to route_to(
          'organizations/artifact_registry_repositories#index',
          organization_path: organization.path,
          slug: 'any-slug'
        )
    end

    it 'routes a deep sub-path to the same action through the vueroute catch-all' do
      expect(get("/o/#{organization.path}/-/artifact_registry/any-slug/repositories/some/deep/link"))
        .to route_to(
          'organizations/artifact_registry_repositories#index',
          organization_path: organization.path,
          slug: 'any-slug',
          vueroute: 'some/deep/link'
        )
    end

    it 'keeps a dotted deep segment in the vueroute rather than parsing it as a format' do
      expect(get("/o/#{organization.path}/-/artifact_registry/any-slug/repositories/deep/file.json"))
        .to route_to(
          'organizations/artifact_registry_repositories#index',
          organization_path: organization.path,
          slug: 'any-slug',
          vueroute: 'deep/file.json'
        )
    end
  end

  describe 'settings route' do
    it 'routes the settings path to settings/artifact_registry#show' do
      expect(get("/o/#{organization.path}/-/settings/artifact_registry"))
        .to route_to(
          'organizations/settings/artifact_registry#show',
          organization_path: organization.path
        )
    end
  end
end
