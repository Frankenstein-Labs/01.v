# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportSources, feature_category: :importers do
  describe '.import_table' do
    it 'includes specific EE imports types when the license supports them' do
      stub_licensed_features(custom_project_templates: true)

      expect(described_class.ee_import_table).not_to be_empty
      expect(described_class.import_table).to include(*described_class.ee_import_table)
    end
  end

  describe '.project_template_importers' do
    it 'includes the custom project template importer' do
      expect(described_class.project_template_importers).to include('gitlab_custom_project_template')
    end
  end

  describe '.template?' do
    subject { described_class.template?(template) }

    context 'when importer is project template importer' do
      let(:template) { 'gitlab_custom_project_template' }

      it { is_expected.to be_truthy }
    end
  end
end
