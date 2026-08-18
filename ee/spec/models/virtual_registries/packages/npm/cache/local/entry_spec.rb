# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Cache::Local::Entry, feature_category: :virtual_registry do
  subject(:entry) { build(:virtual_registries_packages_npm_cache_local_entry) }

  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).required
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Npm::Upstream')
        .required
        .inverse_of(:cache_local_entries)
    end

    it 'belongs to a package file' do
      is_expected.to belong_to(:package_file)
        .class_name('Packages::PackageFile')
        .required
    end
  end
end
