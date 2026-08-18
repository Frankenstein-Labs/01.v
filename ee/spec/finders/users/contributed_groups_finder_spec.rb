# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::ContributedGroupsFinder, feature_category: :user_profile do
  let(:finder) { described_class.new(source_user) }
  let(:source_user) { create(:user) }

  let!(:public_group) { create(:group, :public) }
  let!(:wiki_only_group) { create(:group, :private) }
  let!(:private_group) { create(:group, :private) }
  let!(:internal_group) { create(:group, :internal) }

  before do
    public_group.add_maintainer(source_user)
    wiki_only_group.add_maintainer(source_user)
    private_group.add_maintainer(source_user)
    private_group.add_developer(current_user) if current_user

    [public_group, internal_group, private_group].each do |group|
      create(:event, :epic_create_event, group: group, author: source_user, target: create(:epic, group: group))
    end

    [public_group, internal_group, private_group, wiki_only_group].each do |group|
      create(
        :event,
        group: group,
        project: nil,
        author: source_user,
        action: :commented,
        target: create(
          :note,
          author: source_user,
          project: nil,
          noteable: create(:wiki_page_meta, :for_wiki_page, container: group)
        )
      )
    end
  end

  describe '#execute' do
    subject(:groups) { finder.execute(current_user, include_private_contributions: include_private_contributions) }

    let(:include_private_contributions) { false }

    describe 'activity without a current user' do
      let(:current_user) { nil }

      it 'returns only public groups' do
        expect(groups).to contain_exactly(public_group)
      end

      context 'when private contributions are included' do
        let(:include_private_contributions) { true }

        it 'returns all groups' do
          expect(groups).to contain_exactly(public_group, internal_group, private_group, wiki_only_group)
        end
      end
    end

    describe 'activity with a current user' do
      let(:current_user) { create(:user) }

      it 'retuns all groups visible to user' do
        expect(groups).to contain_exactly(public_group, internal_group, private_group)
      end

      context 'for user with private profile' do
        let(:source_user) { create(:user, private_profile: true) }

        it 'does not return contributed groups' do
          expect(groups).to be_empty
        end
      end
    end
  end
end
