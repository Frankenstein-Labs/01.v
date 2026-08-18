# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportExport::Importer, feature_category: :importers do
  let(:user) { create(:user) }
  let(:test_path) { "#{Dir.tmpdir}/importer_spec" }
  let(:shared) { project.import_export_shared }
  let(:import_file) { fixture_file_upload('spec/features/projects/import_export/test_project_export.tar.gz') }
  let(:project) { create(:project, creator: user) }

  subject(:importer) { described_class.new(project) }

  before do
    allow(Gitlab::ImportExport).to receive(:storage_path).and_return(test_path)
    allow_next_instance_of(Gitlab::ImportExport::FileImporter) do |instance|
      allow(instance).to receive(:remove_import_file)
    end
    stub_uploads_object_storage(FileUploader)

    FileUtils.mkdir_p(shared.export_path)
    ImportExportUpload.create!(project: project, import_file: import_file, user: user)
    allow(FileUtils).to receive(:rm_rf).and_call_original
  end

  after do
    FileUtils.rm_rf(test_path)
  end

  describe '#execute' do
    context 'when project is a custom template import' do
      before do
        allow(project).to receive(:gitlab_custom_project_template_import?).and_return(true)
      end

      it 'calls RepositorySquashRestorer' do
        expect_next_instance_of(Gitlab::ImportExport::Project::RepositorySquashRestorer) do |restorer|
          expect(restorer).to receive(:restore).and_return(true)
        end

        importer.execute
      end

      it 'calls RepositorySquashRestorer after RepoRestorer' do
        call_order = []

        allow_next_instance_of(Gitlab::ImportExport::Project::RepositorySquashRestorer) do |instance|
          allow(instance).to receive(:restore) do
            call_order << :squash_restorer
            true
          end
        end

        # WikiRestorer is actually a RepoRestorer for wiki, so we track each RepoRestorer call
        repo_restorer_count = 0
        allow_next_instance_of(Gitlab::ImportExport::RepoRestorer) do |instance|
          allow(instance).to receive(:restore) do
            repo_restorer_count += 1
            call_order << :"repo_restorer_#{repo_restorer_count}"
            true
          end
        end

        importer.execute

        # repo_restorer_1 is the main repo, repo_restorer_2 is wiki
        expect(call_order).to include(:repo_restorer_1, :squash_restorer)
        expect(call_order.index(:squash_restorer)).to be > call_order.index(:repo_restorer_1)
      end

      it 'calls CustomTemplateRestorer' do
        expect_next_instance_of(Gitlab::ImportExport::Project::CustomTemplateRestorer) do |restorer|
          expect(restorer).to receive(:restore).and_return(true)
        end

        importer.execute
      end

      it 'calls CustomTemplateRestorer after SnippetsRepoRestorer' do
        call_order = []

        allow_next_instance_of(Gitlab::ImportExport::SnippetsRepoRestorer) do |instance|
          allow(instance).to receive(:restore) do
            call_order << :snippets_repo_restorer
            true
          end
        end

        allow_next_instance_of(Gitlab::ImportExport::Project::CustomTemplateRestorer) do |instance|
          allow(instance).to receive(:restore) do
            call_order << :custom_template_restorer
            true
          end
        end

        importer.execute

        expect(call_order).to include(:snippets_repo_restorer, :custom_template_restorer)
        expect(call_order.index(:custom_template_restorer)).to be > call_order.index(:snippets_repo_restorer)
      end

      context 'with template_project_id' do
        it 'initializes the CustomTemplateRestorer' do
          project.build_or_assign_import_data(data: { template_project_id: project.id })

          expect_next_instance_of(Gitlab::ImportExport::Project::CustomTemplateRestorer) do |restorer|
            expect(restorer).to receive(:restore).and_call_original
          end

          importer.execute
        end
      end
    end

    context 'when project is not a custom template import' do
      before do
        allow(project).to receive(:gitlab_custom_project_template_import?).and_return(false)
      end

      it 'does not call the CustomTemplateRestorer' do
        expect(Gitlab::ImportExport::Project::CustomTemplateRestorer).not_to receive(:new)

        importer.execute
      end

      it 'does not call the RepositorySquashRestorer' do
        expect(Gitlab::ImportExport::Project::RepositorySquashRestorer).not_to receive(:new)

        importer.execute
      end
    end
  end
end
