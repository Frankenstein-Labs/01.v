# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Repositories::RepoType, feature_category: :source_code_management do
  describe Gitlab::GlRepository::WIKI do
    context 'with group wiki' do
      let_it_be_with_reload(:wiki) { create(:group_wiki) }

      it_behaves_like 'a repo type' do
        let(:expected_id) { wiki.group.id }
        let(:expected_identifier) { "group-#{expected_id}-wiki" }
        let(:expected_suffix) { '.wiki' }
        let(:expected_container) { wiki }
        let(:expected_repository) do
          ::Repository.new(wiki.full_path, wiki, shard: wiki.repository_storage,
            disk_path: wiki.disk_path, repo_type: described_class)
        end
      end

      describe '#identifier_for_container' do
        subject { described_class.identifier_for_container(wiki.group) }

        it { is_expected.to eq("group-#{wiki.group.id}-wiki") }
      end
    end
  end
end
