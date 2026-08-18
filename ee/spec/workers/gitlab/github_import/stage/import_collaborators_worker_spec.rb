# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Stage::ImportCollaboratorsWorker, feature_category: :importers do
  let(:client) { instance_double(Gitlab::GithubImport::Client) }
  let_it_be(:group) { create(:group, membership_lock: true) }
  let_it_be(:project) do
    create(:project, :github_import, group: group).tap do |project|
      project.build_or_assign_import_data(data: { optional_stages: { collaborators_import: true } }).save!
    end
  end

  subject(:worker) { described_class.new }

  describe '#import' do
    context 'when direct project membership is restricted' do
      it 'skips collaborators import and calls next stage' do
        expect(Gitlab::GithubImport::Importer::CollaboratorsImporter).not_to receive(:new)

        expect(Gitlab::GithubImport::AdvanceStageWorker)
          .to receive(:perform_async)
          .with(project.id, {}, 'issues_and_diff_notes')

        worker.import(client, project)
      end
    end
  end
end
