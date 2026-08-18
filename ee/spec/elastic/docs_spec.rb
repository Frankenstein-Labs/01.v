# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Elastic migration documentation', feature_category: :global_search do
  let(:migration_files) { Dir.glob('ee/elastic/migrate/*.rb') }
  let(:dictionary_files) { Dir.glob('ee/elastic/docs/*.yml') }

  it 'has a dictionary record for every migration file' do
    migrations = migration_files.map { |f| f.gsub('ee/elastic/migrate/', '').gsub('.rb', '') }
    dictionaries = dictionary_files.map { |f| f.gsub('ee/elastic/docs/', '').gsub('.yml', '') }

    missing_dictionary_records = migrations - dictionaries

    message = "Expected dictionary files to be present in ee/elastic/docs/ for migrations #{missing_dictionary_records}"
    expect(missing_dictionary_records).to be_empty, message
  end

  it 'has valid metadata for non-obsolete migrations' do
    required_keys = %w[name version description group milestone introduced_by_url obsolete]
    group_label_pattern = /\Agroup::[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*\z/
    milestone_pattern = /\A\d+\.\d+\z/

    failed = []

    dictionary_files.each do |file|
      content = YAML.safe_load_file(file)

      next if content['obsolete']

      problems = []

      missing_keys = required_keys - content.keys
      problems << "missing keys: #{missing_keys.join(', ')}" if missing_keys.any?

      version_from_filename = File.basename(file).split('_').first
      if content['version'].to_s != version_from_filename
        problems << "version #{content['version'].inspect} does not match filename prefix " \
          "#{version_from_filename.inspect}"
      end

      unless content['group'].is_a?(String) && content['group'].match?(group_label_pattern)
        problems << "group #{content['group'].inspect} must match #{group_label_pattern.inspect}"
      end

      unless content['milestone'].is_a?(String) && content['milestone'].match?(milestone_pattern)
        problems << "milestone #{content['milestone'].inspect} must match #{milestone_pattern.inspect}"
      end

      unless content['obsolete'] == false
        problems << "obsolete must be the boolean false, got #{content['obsolete'].inspect}"
      end

      failed << "#{file}: #{problems.join('; ')}" if problems.any?
    end

    expect(failed).to be_empty,
      "Non-obsolete migration docs have invalid metadata:\n#{failed.join("\n")}"
  end

  it 'defines skip keys for skipped migrations' do
    failed = []
    dictionaries = {}
    skip_keys = %w[skippable skip_condition]

    dictionary_files.each do |file|
      version = file.split('/').last.split('_').first
      dictionaries[version] = file
    end

    Elastic::DataMigrationService.migrations.select(&:skippable?).each do |migration|
      dictionary = dictionaries[migration.version.to_s]
      dictionary_keys = YAML.load_file(dictionary).keys

      failed << migration.name unless skip_keys.all? { |key| dictionary_keys.include?(key) }
    end

    message = "Expected dictionary file for #{failed.join(', ')} to define #{skip_keys.join(', ')}"
    expect(failed).to be_empty, message
  end
end
