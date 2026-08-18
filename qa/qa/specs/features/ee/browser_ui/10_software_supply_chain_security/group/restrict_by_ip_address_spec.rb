# frozen_string_literal: true

module QA
  RSpec.describe 'Software Supply Chain Security', feature_category: :system_access do
    describe 'Group access', :requires_admin, :skip_live_env do
      let!(:current_ip_address) do
        Flow::Login.while_signed_in(as: user) { Runtime::User::Store.admin_user.get_user_ip_address(user.id) }
      end

      let(:user) { Runtime::User::Store.test_user }
      let(:api_client) { user.api_client }
      let(:admin_api_client) { Runtime::User::Store.admin_api_client }

      let(:sandbox_group) { create(:sandbox, api_client: admin_api_client) }
      let(:group) { create(:group, sandbox: sandbox_group, api_client: admin_api_client) }
      let(:project) { create(:project, :with_readme, group: group, api_client: admin_api_client) }

      before do
        project.add_member(user)
        set_ip_address_restriction_to(ip_address)
      end

      context 'when restricted by another ip address' do
        let(:ip_address) { get_fake_ip_based_on(current_ip_address) }

        context 'with UI' do
          it 'denies access' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!
            expect(page).to have_text('Page not found')
            page.go_back

            group.visit!
            expect(page).to have_text('Page not found')
            page.go_back
          end
        end

        context 'with API' do
          it 'denies access' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(404)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          it 'denies access' do
            expect { push_a_project_with_ssh_key(key) }.to raise_error(
              QA::Support::Run::CommandError, /fatal: Could not read from remote repository/
            )
          end
        end
      end

      context 'when restricted by user\'s ip address' do
        let(:ip_address) { current_ip_address }

        context 'with UI' do
          it 'allows access' do
            Flow::Login.sign_in(as: user)

            group.sandbox.visit!
            expect(page).to have_text(group.sandbox.path)

            group.visit!
            expect(page).to have_text(group.path)
          end
        end

        context 'with API' do
          it 'allows access' do
            request = create_request("/groups/#{sandbox_group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)

            request = create_request("/groups/#{group.id}")
            response = Support::API.get request.url
            expect(response.code).to eq(200)
          end
        end

        # Note: If you run this test against GDK make sure you've enabled sshd
        # See: https://gitlab.com/gitlab-org/gitlab-qa/blob/master/docs/run_qa_against_gdk.md
        context 'with SSH', :requires_sshd do
          let(:key) do
            create(:ssh_key, api_client: api_client, title: "ssh key for allowed ip restricted access #{Time.now.to_f}")
          end

          it 'allows access' do
            expect { push_a_project_with_ssh_key(key, 2) }.not_to raise_error
          end
        end
      end

      private

      def push_a_project_with_ssh_key(key, attempts = 1)
        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.group = sandbox_group
          push.ssh_key = key
          push.branch_name = "new_branch_#{SecureRandom.hex(8)}"
          push.max_attempts = attempts
        end
      end

      def set_ip_address_restriction_to(ip_address)
        sandbox_group.set_ip_restriction_range(ip_address)
      end

      def get_fake_ip_based_on(address)
        split_address = address.split(".")

        current_3rd_part = split_address[2].to_i
        updated_3rd_part = current_3rd_part < 255 ? current_3rd_part + 1 : 1
        split_address[2] = updated_3rd_part

        split_address.join(".")
      end

      def create_request(api_endpoint)
        Runtime::API::Request.new(api_client, api_endpoint)
      end
    end
  end
end
