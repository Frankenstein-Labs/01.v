# frozen_string_literal: true

module QA
  RSpec.describe 'Systems', :orchestrated, :geo, feature_category: :geo_replication do
    describe 'GitLab HTTP push' do
      include QA::EE::Support::Helpers::GeoGraphQl # rubocop:disable Cop/InjectEnterpriseEditionModule -- QA helpers

      let(:file_name) { 'README.md' }

      context 'when regular git commit' do
        it 'project repository successfully replicates to secondary Geo site' do
          file_content = 'This is a Geo project! Commit from primary.'
          project = nil

          QA::Flow::Login.while_signed_in do
            project = create(:project, name: 'geo-project', description: 'Geo test project for http push')

            Resource::Repository::ProjectPush.fabricate! do |push|
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end.project.visit!

            Page::Project::Show.perform do |show|
              show.wait_for_repository_replication

              expect(page).to have_content(file_name)
              expect(page).to have_content(file_content)
            end
          end

          QA::Runtime::Logger.info("Created project with ID: #{project.id}")

          admin_api_client = Runtime::API::Client.as_admin

          wait_for_project_repository_replication(
            admin_api_client,
            project_id: project.id
          )

          QA::Runtime::Logger.info("Project #{project.id} repository successfully replicated to secondary")
        end
      end

      context 'when git-lfs commit' do
        it 'project repository with LFS successfully replicates to secondary Geo site' do
          file_content = "LFS content #{SecureRandom.hex(16)}"
          project = nil
          new_lfs_ids = nil

          admin_api_client = Runtime::API::Client.as_admin

          QA::Flow::Login.while_signed_in do
            project = create(:project, name: 'geo-project', description: 'Geo test project for http lfs push')

            lfs_ids_before_push = primary_lfs_object_ids(admin_api_client)
            QA::Runtime::Logger.info("LFS object IDs before push: #{lfs_ids_before_push.size} objects")

            push = Resource::Repository::ProjectPush.fabricate! do |push|
              push.use_lfs = true
              push.project = project
              push.file_name = file_name
              push.file_content = "# #{file_content}"
              push.commit_message = 'Add README.md'
            end

            expect(push.output).to match(/Locking support detected on remote/)

            lfs_ids_after_push = primary_lfs_object_ids(admin_api_client)
            new_lfs_ids = lfs_ids_after_push - lfs_ids_before_push
            QA::Runtime::Logger.info("New LFS object IDs after push: #{new_lfs_ids.to_a}")
          end

          # This checks all LFS objects created since the push, which is a wider
          # net than necessary. The LFS object database ID is not exposed in the
          # GitLab UI or API (only the SHA256 OID is), so we compare the set of
          # all LFS object IDs before and after the push to find new ones.
          new_lfs_ids.each do |lfs_object_id|
            wait_for_lfs_object_replication(admin_api_client, lfs_object_id: lfs_object_id)
          end

          QA::Runtime::Logger.info(
            "LFS object #{new_lfs_ids} successfully replicated to secondary"
          )
        end
      end
    end
  end
end
