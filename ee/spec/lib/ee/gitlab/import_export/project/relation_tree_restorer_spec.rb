# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Project::RelationTreeRestorer, feature_category: :importers do
  let_it_be_with_reload(:importable) do
    create(:project, :builds_enabled, :issues_disabled, name: 'project', path: 'project')
  end

  let(:path) { 'spec/fixtures/lib/gitlab/import_export/complex/tree' }
  let(:relation_reader) { Gitlab::ImportExport::Json::NdjsonReader.new(path) }
  let(:reader) { Gitlab::ImportExport::Reader.new(shared: shared) }
  let(:relation_tree_restorer) do
    described_class.new(
      user: user,
      shared: shared,
      relation_reader: relation_reader,
      object_builder: Gitlab::ImportExport::Project::ObjectBuilder,
      members_mapper: members_mapper,
      relation_factory: Gitlab::ImportExport::Project::RelationFactory,
      reader: reader,
      importable: importable,
      importable_path: 'project',
      importable_attributes: attributes
    )
  end

  include_context 'relation tree restorer shared context' do
    let(:importable_name) { 'project' }
  end

  subject(:restore) { relation_tree_restorer.restore }

  describe 'custom project template import' do
    context 'when importing from a custom project template' do
      before do
        allow(importable).to receive(:gitlab_custom_project_template_import?).and_return(true)
      end

      it 'excludes ci_pipelines but includes other relations' do
        expect(restore).to be(true)

        project = Project.find_by_path('project')

        expect(project.ci_pipelines.count).to eq(0)
        expect(project.labels.count).to be > 0
        expect(project.issues.count).to be > 0
      end
    end

    context 'when importing from a regular project export' do
      before do
        allow(importable).to receive(:gitlab_custom_project_template_import?).and_return(false)
      end

      it 'includes ci_pipelines' do
        expect(restore).to be(true)

        project = Project.find_by_path('project')

        expect(project.ci_pipelines.count).to be > 0
      end
    end
  end
end
