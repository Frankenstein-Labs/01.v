# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupWikiRepository, feature_category: :wiki do
  describe 'associations' do
    it { is_expected.to belong_to(:shard) }
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:shard) }
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:disk_path) }

    context 'uniqueness' do
      subject { described_class.new(shard: build(:shard), group: build(:group), disk_path: 'path') }

      it { is_expected.to validate_uniqueness_of(:group) }
      it { is_expected.to validate_uniqueness_of(:disk_path) }
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:group_wiki_repository_state)
          .class_name('Geo::GroupWikiRepositoryState')
          .inverse_of(:group_wiki_repository)
          .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let_it_be(:group) { create(:group) }

      let(:verifiable_model_record) { build(:group_wiki_repository, group: group) }
      let(:unverifiable_model_record) { nil }
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }

      # Wiki for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:group_wiki_repository, group: group_1)
      end

      # Wiki for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:group_wiki_repository, group: nested_group_1)
      end

      # Wiki in a shard name that doesn't actually exist
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:group_wiki_repository, group: group_2, shard_name: 'broken')
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end
end
