# frozen_string_literal: true

module QA
  RSpec.describe 'Plan', feature_category: :wiki do
    describe 'Testing group wiki' do
      let(:initial_wiki) { create(:group_wiki_page) }

      before do
        Flow::Login.sign_in
      end

      it 'can delete a group wiki page' do
        initial_wiki.visit!

        EE::Page::Group::Wiki::Show.perform(&:delete_page)

        EE::Page::Group::Wiki::Show.perform do |wiki|
          expect(wiki).to have_no_page
        end
      end
    end
  end
end
