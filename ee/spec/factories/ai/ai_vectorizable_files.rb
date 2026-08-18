# frozen_string_literal: true

FactoryBot.define do
  factory :ai_vectorizable_file, class: 'Ai::VectorizableFile' do
    name { 'file.txt' }
    file { fixture_file_upload('ee/spec/fixtures/ai/vectorizable_file.txt', 'application/octet-stream') }
    project
  end
end
