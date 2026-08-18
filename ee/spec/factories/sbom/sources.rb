# frozen_string_literal: true

FactoryBot.define do
  factory :sbom_source, class: 'Sbom::Source' do
    association :organization, factory: :organization

    source_type { :dependency_scanning }

    transient do
      sequence(:input_file_path) { |n| "subproject-#{n}/package-lock.json" }
      sequence(:source_file_path) { |n| "subproject-#{n}/package.json" }
      sequence(:image_name) { |n| "image-#{n}" }
      packager_name { 'npm' }
      operating_system { { 'name' => 'Photon OS', 'version' => '5.0' } }
    end

    source do
      if source_type == :dependency_scanning
        {
          'category' => 'development',
          'input_file' => { 'path' => input_file_path },
          'source_file' => { 'path' => source_file_path },
          'package_manager' => { 'name' => packager_name },
          'language' => { 'name' => 'JavaScript' }
        }
      else
        {
          'category' => 'development',
          'image' => { 'name' => image_name, 'tag' => 'v1' },
          'operating_system' => operating_system
        }
      end
    end
  end
end
