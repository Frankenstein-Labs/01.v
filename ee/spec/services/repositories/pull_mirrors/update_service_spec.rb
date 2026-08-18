# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::PullMirrors::UpdateService, feature_category: :source_code_management do
  subject(:service) { described_class.new(project, user, params) }

  let_it_be_with_reload(:project) { create(:project, :empty_repo) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:params) do
    {
      import_url: url,
      mirror: enabled,
      import_data_attributes: {
        auth_method: auth_method,
        user: cred_user,
        password: cred_password
      },
      only_mirror_protected_branches: only_protected_branches
    }
  end

  let(:url) { 'https://example.com' }
  let(:enabled) { true }
  let(:auth_method) { 'password' }
  let(:cred_user) { 'admin' }
  let(:cred_password) { 'pass' }
  let(:only_protected_branches) { true }

  describe '#execute', :aggregate_failures do
    subject(:execute) { service.execute }

    let(:updated_project) { execute.payload[:project] }

    before do
      allow_next_instance_of(Import::ValidateRemoteGitEndpointService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.success)
      end
    end

    it 'updates a pull mirror' do
      is_expected.to be_success

      expect(updated_project).to have_attributes(
        unsafe_import_url: "https://#{cred_user}:#{cred_password}@example.com",
        mirror: enabled,
        only_mirror_protected_branches: only_protected_branches,
        id: project.id
      )

      expect(updated_project.import_data).to have_attributes(
        auth_method: auth_method,
        user: cred_user,
        password: cred_password
      )
    end

    it 'triggers a pull mirror update process' do
      expect(UpdateAllMirrorsWorker).to receive(:perform_async)

      is_expected.to be_success
    end

    context 'when user does not have permissions' do
      let(:user) { nil }

      it 'returns an error' do
        is_expected.to be_error
        expect(execute.message).to eq('Access Denied')
      end
    end

    context 'when only url is provided' do
      let(:params) { { import_url: 'https://example.com' } }

      it 'creates a disabled mirror' do
        is_expected.to be_success

        expect(updated_project).to have_attributes(
          import_url: "https://example.com",
          mirror: false,
          id: project.id
        )

        expect(updated_project.import_state).to be_present
        expect(updated_project.import_data).to be_present
      end
    end

    context 'when credentials are passed separately' do
      let(:params) { super().merge(credentials: { user: credentials_user, password: credentials_password }) }
      let(:credentials_user) { 'u$/r' }
      let(:credentials_password) { 'p@$$/ord' }

      it 'prefers these credentials' do
        is_expected.to be_success

        expect(updated_project.import_data).to have_attributes(
          auth_method: auth_method,
          user: credentials_user,
          password: credentials_password
        )
      end
    end

    context 'when the mirror already has stored credentials' do
      before do
        project.import_url = 'https://victim:secret@legit.example.com/repo.git'
        project.build_or_assign_import_data(credentials: { user: 'victim', password: 'secret' })
        project.save!
      end

      context 'when the URL is changed' do
        context 'without supplying credentials' do
          let(:params) { { mirror: true, username_only_import_url: 'https://attacker.example.com/repo.git' } }

          it 'clears the stored password' do
            is_expected.to be_success

            expect(updated_project.import_data.password).to be_blank
          end
        end

        context 'with a new password' do
          let(:params) do
            {
              mirror: true,
              import_url: 'https://attacker.example.com/repo.git',
              credentials: { user: 'attacker', password: 'newpass' }
            }
          end

          it 'stores the new password' do
            is_expected.to be_success

            expect(updated_project.import_data).to have_attributes(user: 'attacker', password: 'newpass')
          end
        end

        context 'with credentials that omit the password' do
          let(:params) do
            {
              mirror: true,
              username_only_import_url: 'https://attacker.example.com/repo.git',
              credentials: { user: 'victim' }
            }
          end

          it 'clears the stored password' do
            is_expected.to be_success

            expect(updated_project.import_data.password).to be_blank
          end
        end
      end
    end

    context 'when mirror is disabled' do
      let(:enabled) { false }

      it 'removes import data' do
        is_expected.to be_success
        expect(updated_project.reload.import_data).to be_nil
      end
    end

    context 'when previous import had an error' do
      before do
        create(:import_state, project: project, last_error: 'Error')
      end

      it 'cleans up the previous error' do
        is_expected.to be_success
        expect(updated_project.reload.import_state.last_error).to be_nil
      end
    end

    context 'when parameters were not provided' do
      let(:params) { {} }

      it 'returns an error' do
        is_expected.to be_error
        expect(execute.message.full_messages).to include(/Url is missing/)
      end

      context 'when import state already existed' do
        before do
          create(:import_state, project: project)
        end

        it 'allows empty parameters input' do
          is_expected.to be_success
          expect(updated_project.reload.import_state).to be_present
        end
      end
    end

    context 'when params are invalid' do
      let(:url) { 'not_a_url' }

      it 'returns an error' do
        is_expected.to be_error
        expect(execute.message.full_messages).to include(/Import URL is blocked/)
      end
    end

    context 'when URL validation is enabled' do
      before do
        stub_feature_flags(validate_pull_mirror_url: true)
      end

      context 'when import URL is not accessible' do
        let(:url) { 'http://not-existing-url-1/git' }

        before do
          allow_next_instance_of(Import::ValidateRemoteGitEndpointService) do |service|
            allow(service).to receive(:execute).and_return(
              ServiceResponse.error(message: 'Unable to access repository with the URL and credentials provided')
            )
          end
        end

        it 'returns an error' do
          is_expected.to be_error
          expect(execute.message.full_messages).to(
            include(/Unable to access repository with the URL and credentials provided/)
          )
        end
      end
    end

    context 'when URL validation is disabled' do
      before do
        stub_feature_flags(validate_pull_mirror_url: false)
      end

      context 'with an inaccessible URL' do
        it 'allows the update without validation' do
          service_with_inaccessible_url = described_class.new(project, user, params.merge(import_url: 'http://not-existing-url-1/git'))
          result = service_with_inaccessible_url.execute

          expect(result).to be_success
        end
      end
    end

    context 'when import_url is blank' do
      let(:params) { { import_url: '' } }

      before do
        create(:import_state, project: project)
      end

      it 'skips validation' do
        expect(Import::ValidateRemoteGitEndpointService).not_to receive(:new)

        is_expected.to be_success
      end
    end

    context 'when mirror is disabled and url is provided' do
      let(:enabled) { false }

      it 'skips validation' do
        expect(Import::ValidateRemoteGitEndpointService).not_to receive(:new)

        is_expected.to be_success
      end
    end
  end
end
