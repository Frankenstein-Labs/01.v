# frozen_string_literal: true

module QA
  RSpec.describe 'Create', feature_category: :source_code_management do
    describe 'Codeowners', :smoke, :requires_admin do
      let(:files) do
        [
          {
            name: 'file.txt',
            content: 'foo'
          },
          {
            name: 'README.md',
            content: 'bar'
          }
        ]
      end

      let(:project) { create(:project, name: 'codeowners') }

      let(:user) { create(:user) }
      let(:user2) { create(:user) }

      let(:codeowners_file_content) do
        <<-CONTENT
            * @#{user2.username}
            *.txt @#{user.username}
        CONTENT
      end

      before do
        Flow::Login.sign_in

        project.add_member(user)
        project.add_member(user2)

        create(:commit, project: project, commit_message: 'Add CODEOWNERS and test files', actions: [
          { action: 'create', file_path: 'file.txt', content: 'foo' },
          { action: 'create', file_path: 'README.md', content: 'bar' },
          { action: 'create', file_path: 'CODEOWNERS', content: codeowners_file_content }
        ])
      end

      it 'displays owners specified in CODEOWNERS file' do
        project.visit!

        # Check the files and code owners
        Page::Project::Show.perform { |project_page| project_page.click_file 'file.txt' }
        Page::File::Show.perform do |file|
          file.reveal_code_owners
          expect(file).to have_code_owners_container, "Expected Code owners section to be present for file"
        end

        expect(page).to have_content(user.name), "Expected \"#{user.name}\" to be in Code owners section"
        expect(page).not_to have_content(user2.name)

        project.visit!
        Page::Project::Show.perform { |project_page| project_page.click_file 'README.md' }
        Page::File::Show.perform(&:reveal_code_owners)

        expect(page).to have_content(user2.name), "Expected \"#{user2.name}\" to be in Code owners section"
        expect(page).not_to have_content(user.name)
      end
    end
  end
end
