# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::NewDropdownHelper, feature_category: :navigation do
  describe '#new_dropdown_view_model' do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:group) { build_stubbed(:group) }

    let(:view_model) { helper.new_dropdown_view_model(group: group, project: nil) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).and_return(false)
      allow(helper).to receive(:can?).with(user, :create_work_item, group).and_return(true)
    end

    shared_examples 'work item menu' do
      it 'shows create work item menu item' do
        epic_item = {
          title: 'In this group',
          menu_items: [
            ::Gitlab::Nav::TopNavMenuItem.build(
              id: 'new_group_work_item',
              title: 'New work item',
              component: 'create_new_work_item_modal'
            )
          ]
        }

        expect(view_model[:menu_sections][0]).to eq(epic_item)
      end
    end

    context 'when epics licensed feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      it_behaves_like 'work item menu'
    end

    context 'when group wikis licensed feature is available' do
      before do
        stub_licensed_features(group_wikis: true)
        allow(helper).to receive(:can?).with(user, :create_wiki, group).and_return(true)
      end

      it 'shows new wiki page menu item' do
        wiki_item = ::Gitlab::Nav::TopNavMenuItem.build(
          id: 'new_wiki_page',
          title: 'New wiki page',
          href: group_wikis_new_path(group)
        )

        menu_items = view_model[:menu_sections][0][:menu_items]
        expect(menu_items).to include(wiki_item)
      end
    end

    context 'when group wikis licensed feature is not available' do
      before do
        stub_licensed_features(group_wikis: false)
      end

      it 'does not show new wiki page menu item' do
        menu_items = view_model[:menu_sections][0][:menu_items]
        expect(menu_items).not_to include(hash_including(id: 'new_wiki_page'))
      end
    end
  end
end
