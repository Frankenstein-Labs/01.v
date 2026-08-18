# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::Constants, feature_category: :code_suggestions do
  let(:config_files_dir) { Rails.root.join('ee/lib/ai/context/dependencies/config_files') }
  let(:ignored_file_names) { ['base.rb', 'constants.rb', 'parsing_errors.rb'] }

  subject(:config_file_class_names) { described_class::CONFIG_FILE_CLASSES.map { |klass| klass.name.demodulize } }

  it 'includes the names of all config file child classes within /config_files' do
    file_paths = Dir.glob("#{config_files_dir}/*.rb") - ignored_file_names.map { |name| "#{config_files_dir}/#{name}" }
    class_names_in_config_files_dir = file_paths.map { |path| File.basename(path, '.rb').camelize }

    expect(config_file_class_names).to match_array(class_names_in_config_files_dir)
  end
end
