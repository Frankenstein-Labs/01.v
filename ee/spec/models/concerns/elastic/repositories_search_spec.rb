# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::RepositoriesSearch, feature_category: :global_search do
  include EE::GeoHelpers

  let(:model) do
    Class.new do
      include Elastic::RepositoriesSearch

      def project
        Project.new
      end
    end.new
  end

  describe '#index_commits_and_blobs' do
    subject(:index_commits_and_blobs) { model.index_commits_and_blobs }

    using RSpec::Parameterized::TableSyntax

    where(:geo, :commit_indexing_expected) do
      :disabled  | true
      :primary   | true
      :secondary | false
    end

    with_them do
      before do
        public_send(:"stub_#{geo}_node") unless geo == :disabled
      end

      it 'initiates commits reindexing when indexing is expected' do
        if commit_indexing_expected
          expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(model.project.id)
        else
          expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)
        end

        index_commits_and_blobs
      end
    end
  end
end
