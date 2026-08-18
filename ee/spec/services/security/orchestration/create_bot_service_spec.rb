# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Orchestration::CreateBotService, feature_category: :security_policy_management do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:project) { create(:project, group: group, organization: organization) }
  let_it_be(:user) { create(:user, organization: project.organization) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, project: project)
  end

  let(:skip_authorization) { false }
  let(:current_user) { user }

  subject(:execute_service) do
    described_class.new(project, current_user, skip_authorization: skip_authorization).execute
  end

  context 'when current_user is missing' do
    let(:current_user) { nil }

    it 'raises an error', :aggregate_failures do
      expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)
    end

    it 'logs the authorization failure' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          event: 'security_policy_bot_creation',
          message: 'User not authorized to create security policy bot'
        )
      )

      expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)
    end

    context 'when skipping authorization' do
      let(:skip_authorization) { true }

      it 'creates and assigns a bot user', :aggregate_failures do
        expect { execute_service }.to change { User.count }.by(1)
        expect(project.security_policy_bot).to be_present
      end

      context 'when group_allowed_email_domains feature is available' do
        before do
          stub_licensed_features(group_allowed_email_domains: true)
          create(:allowed_email_domain, group: group, domain: 'noreply.gitlab.com')
        end

        it 'creates and assigns a bot user', :aggregate_failures do
          expect { execute_service }.to change { User.count }.by(1)
          expect(project.security_policy_bot).to be_present
        end
      end

      context 'when sign up restriction is enabled with email domain allowlist' do
        before do
          stub_application_setting(domain_allowlist: ['example.com'])
        end

        it 'creates and assigns a bot user', :aggregate_failures do
          expect { execute_service }.to change { User.count }.by(1)
          expect(project.security_policy_bot).to be_present
        end

        it 'logs the successful creation and addition' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Creating security policy bot user'
            )
          )

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Successfully created security policy bot user'
            )
          )

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Successfully added security policy bot as guest to project'
            )
          )

          execute_service
        end
      end
    end
  end

  context 'when current_user cannot manage members' do
    it 'raises an error', :aggregate_failures do
      expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)
    end

    it 'logs the authorization failure' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          event: 'security_policy_bot_creation',
          message: 'User not authorized to create security policy bot'
        )
      )

      expect { execute_service }.to raise_error(Gitlab::Access::AccessDeniedError)
    end

    context 'when skipping authorization' do
      let(:skip_authorization) { true }

      it 'creates and assigns a bot user', :aggregate_failures do
        expect { execute_service }.to change { User.count }.by(1)
        expect(project.reload.security_policy_bot).to be_present
      end

      it 'logs the successful creation and addition' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Creating security policy bot user'
          )
        )

        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Successfully created security policy bot user'
          )
        )

        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Successfully added security policy bot as guest to project'
          )
        )

        execute_service
      end

      context 'when bot user is created but adding to project fails with errors' do
        let(:project_member) do
          instance_double(ProjectMember,
            valid?: false,
            errors: instance_double(ActiveModel::Errors, full_messages: ['Error message'])
          )
        end

        before do
          allow(project).to receive(:add_guest).and_return(project_member)
        end

        it 'logs the error and returns the project member' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Creating security policy bot user'
            )
          )

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Failed to add security policy bot as guest to project',
              reason: 'add_guest did not complete successfully: Error message'
            )
          )

          execute_service
        end
      end

      context 'when bot user is created but adding to project returns false instead' do
        before do
          allow(project).to receive(:add_guest).and_return(false)
        end

        it 'logs the error and returns the project member' do
          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Creating security policy bot user'
            )
          )

          expect(Gitlab::AppJsonLogger).to receive(:info).with(
            hash_including(
              event: 'security_policy_bot_creation',
              message: 'Failed to add security policy bot as guest to project',
              reason: 'unknown'
            )
          )

          execute_service
        end
      end
    end
  end

  context 'when current_user can manage members' do
    before do
      project.add_owner(current_user)
    end

    it 'creates and assigns a bot user', :aggregate_failures do
      expect { execute_service }.to change { User.count }.by(1)
      expect(project.security_policy_bot).to be_present
    end

    it 'creates the bot with correct params', :aggregate_failures do
      execute_service

      bot_user = project.security_policy_bot

      expect(bot_user.name).to eq('GitLab Security Policy Bot')
      expect(bot_user.username).to start_with("gitlab_security_policy_project_#{project.id}_bot")
      expect(bot_user.email).to start_with("gitlab_security_policy_project_#{project.id}_bot")
      expect(bot_user.user_type).to eq('security_policy_bot')
      expect(bot_user.external).to eq(true)
      expect(bot_user.avatar).to be_instance_of AvatarUploader
      expect(bot_user.private_profile).to eq(true)
      expect(bot_user.confirmed_at).to be_present
      expect(bot_user.namespace.organization).to eq(project.organization)
    end

    it 'adds the bot user as a guest to the project', :aggregate_failures do
      expect { execute_service }.to change { project.members.count }.by(1)

      bot_user = project.security_policy_bot

      expect(project.members.find_by(user: bot_user).access_level).to eq(Gitlab::Access::GUEST)
    end

    it 'logs the successful creation and addition' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          event: 'security_policy_bot_creation',
          message: 'Creating security policy bot user'
        )
      )

      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          event: 'security_policy_bot_creation',
          message: 'Successfully created security policy bot user'
        )
      )

      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        hash_including(
          event: 'security_policy_bot_creation',
          message: 'Successfully added security policy bot as guest to project'
        )
      )

      execute_service
    end

    context 'when a bot user is already assigned' do
      let_it_be(:bot_user) { create(:user, :security_policy_bot, organization: project.organization) }

      before do
        project.add_guest(bot_user)
      end

      it 'does not assign a new bot user', :aggregate_failures do
        expect { execute_service }.not_to change { User.count }

        expect(project.security_policy_bot.id).to equal(bot_user.id)
      end

      it 'logs nothing' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)

        execute_service
      end
    end

    context 'when a part of the creation fails' do
      before do
        allow(project).to receive(:add_guest).and_raise(StandardError)
      end

      it 'reverts the previous actions' do
        expect { execute_service }.to raise_error(StandardError).and not_change { User.count }
      end

      it 'logs process start and the failure' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Creating security policy bot user'
          )
        )

        expect { execute_service }.to raise_error(StandardError)
      end
    end

    context 'when creating the user fails' do
      before do
        allow_next_instance_of(::Users::CreateBotService) do |users_create_bot_service|
          allow(users_create_bot_service).to receive(:execute).and_return(ServiceResponse.error(message: 'User error'))
        end
      end

      it 'logs process start and the failure' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Creating security policy bot user'
          )
        )

        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(
            event: 'security_policy_bot_creation',
            message: 'Failed to create security policy bot user',
            reason: 'User error'
          )
        )

        execute_service
      end
    end
  end
end
