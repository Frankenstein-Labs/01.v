# frozen_string_literal: true

FactoryBot.define do
  factory :vertex_gitlab_documentation, class: Hash do
    sequence(:url) do |n|
      "http://example.com/path/to/a/doc_#{n}"
    end

    sequence :id
    sequence(:metadata) do |n|
      {
        info: "Description for #{n}",
        source: "path/to/a/doc_#{n}.md",
        source_type: 'doc',
        source_url: "http://example.com/path/to/a/doc_#{n}",
        title: 'title',
        md5sum: 'md5sum',
        filename: "doc_#{n}.md"
      }
    end

    content { 'Some text' }

    skip_create
    initialize_with { attributes }
  end
end
