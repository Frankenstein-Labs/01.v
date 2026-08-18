# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :wiki do
    describe 'Creating pages in group wikis' do
      let(:wiki_title) { 'New Wiki page' }
      let(:wiki_content) { 'New Wiki content' }

      before do
        Flow::Login.sign_in
      end

      context 'when wiki is empty' do
        let(:group) { create(:group) }

        it 'creates a new page', quarantine: {
          type: :broken,
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24049'
        } do
          group.visit!

          Page::Group::Menu.perform(&:go_to_wiki)
          EE::Page::Group::Wiki::Show.perform(&:click_create_your_first_page)

          EE::Page::Group::Wiki::Edit.perform do |edit|
            edit.close_sidebar
            edit.set_title(wiki_title)
            edit.set_content(wiki_content)
            edit.click_submit
          end

          EE::Page::Group::Wiki::Show.perform do |wiki|
            expect(wiki).to have_title(wiki_title)
            expect(wiki).to have_content(wiki_content)
          end
        end
      end

      context 'when wiki has a home page' do
        let(:wiki) { create(:group_wiki_page) }

        it 'adds a second page', quarantine: {
          type: :broken,
          issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24049'
        } do
          wiki.visit!

          EE::Page::Group::Wiki::Show.perform(&:click_new_page)

          EE::Page::Group::Wiki::Edit.perform do |edit|
            edit.close_sidebar
            edit.set_title(wiki_title)
            edit.set_content(wiki_content)
            edit.click_submit
          end

          EE::Page::Group::Wiki::Show.perform do |wiki|
            expect(wiki).to have_title(wiki_title)
            expect(wiki).to have_content(wiki_content)
            wiki.expand_sidebar_if_collapsed
            expect(wiki).to have_page_listed('Home')
          end
        end
      end
    end
  end
end
