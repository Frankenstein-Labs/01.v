# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::UpdateService, feature_category: :user_profile do
  using RSpec::Parameterized::TableSyntax
  let(:user) { create(:user) }

  describe '#execute' do
    context 'updating name' do
      let(:admin) { create(:admin) }

      shared_examples_for 'a user can update the name' do
        it 'updates the name' do
          result = update_user_as(current_user, user, { user: user, name: 'New Name' })

          expect(result).to be_truthy
          expect(user.name).to eq('New Name')
        end
      end

      shared_examples_for 'a user cannot update the name' do
        it 'does not update the name' do
          result = update_user_as(current_user, user, { name: 'New Name' })

          expect(result).to be_truthy
          expect(user.name).not_to eq('New Name')
        end
      end

      context 'when `disable_name_update_for_users` feature is available' do
        before do
          stub_licensed_features(disable_name_update_for_users: true)
        end

        context 'when the ability to update their name is not disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: false)
          end

          it_behaves_like 'a user can update the name' do
            let(:current_user) { user }
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it_behaves_like 'a user can update the name' do
              let(:current_user) { admin }
            end
          end
        end

        context 'when the ability to update their name is disabled for users' do
          before do
            stub_application_setting(updating_name_disabled_for_users: true)
          end

          context 'as a regular user' do
            it_behaves_like 'a user cannot update the name' do
              let(:current_user) { user }
            end
          end

          context 'when admin mode is enabled', :enable_admin_mode do
            it_behaves_like 'a user can update the name' do
              let(:current_user) { admin }
            end
          end

          context 'when admin mode is disabled' do
            it_behaves_like 'a user cannot update the name' do
              let(:current_user) { admin }
            end
          end

          context 'when force: true parameter is passed to service' do
            let(:current_user) { user }

            it 'updates the name' do
              result = update_user_as(current_user, user, { user: user, name: 'New Name', force_name_change: true })

              expect(result).to be_truthy
              expect(user.name).to eq('New Name')
            end
          end
        end
      end

      context 'when `disable_name_update_for_users` feature is not available' do
        before do
          stub_licensed_features(disable_name_update_for_users: false)
        end

        it_behaves_like 'a user can update the name' do
          let(:current_user) { user }
        end

        context 'when admin mode is enabled', :enable_admin_mode do
          it_behaves_like 'a user can update the name' do
            let(:current_user) { admin }
          end
        end

        context 'when admin mode is disabled' do
          it_behaves_like 'a user cannot update the name' do
            let(:current_user) { admin }
          end
        end
      end
    end

    context 'audit events' do
      context 'when licensed' do
        let_it_be_with_reload(:user) { create(:user) }

        before do
          stub_licensed_features(admin_audit_log: true)
        end

        context 'updating administrator status' do
          let_it_be_with_reload(:admin_user) { create(:admin) }

          it 'logs making a user an administrator' do
            expect do
              update_user_as(admin_user, user, admin: true)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq('Changed admin status from false to true')
          end

          it 'logs making an administrator a user' do
            admin = create(:admin)
            expect do
              update_user_as(admin_user, admin, admin: false)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq('Changed admin status from true to false')
          end
        end

        context 'updating auditor status' do
          let_it_be_with_reload(:admin_user) { create(:admin) }

          it 'logs promoting a user to auditor' do
            expect do
              update_user_as(admin_user, user, auditor: true)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq('Changed auditor status from false to true')
          end

          it 'logs demoting an auditor to a regular user' do
            user.update!(auditor: true)
            expect do
              update_user_as(admin_user, user, auditor: false)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq('Changed auditor status from true to false')
          end
        end

        context 'updating external status' do
          let_it_be_with_reload(:admin_user) { create(:admin) }

          # Setting external also cascades changes to projects_limit and can_create_group
          it 'logs flagging a user as external', :aggregate_failures do
            expect do
              update_user_as(admin_user, user, external: true)
            end.to change { AuditEventReader.count }.by(3)

            actions = AuditEventReader.last(3).map { |e| e.present.action }
            expect(actions).to include('Changed external status from false to true')
            expect(actions).to include("Changed projects limit from #{Gitlab::CurrentSettings.default_projects_limit} to 0")
            expect(actions).to include('Changed can create group from true to false')
          end

          it 'logs unflagging an external to an internal user', :aggregate_failures do
            user.update!(external: true)

            expect do
              update_user_as(admin_user, user, external: false)
            end.to change { AuditEventReader.count }.by(3)

            actions = AuditEventReader.last(3).map { |e| e.present.action }
            expect(actions).to include('Changed external status from true to false')
            expect(actions).to include("Changed projects limit from 0 to #{Gitlab::CurrentSettings.default_projects_limit}")
            expect(actions).to include('Changed can create group from false to true')
          end
        end

        context 'updating username' do
          it 'logs audit event' do
            previous_username = user.username
            new_username = 'my_new_username'
            expected_message = "Changed username from #{previous_username} to #{new_username}"

            expect do
              update_user_as_self(user, username: new_username)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq(expected_message)
          end
        end

        context 'updating name' do
          it 'logs audit event' do
            previous_name = user.name
            new_name = 'my_new_name'
            expected_message = "Changed name from #{previous_name} to #{new_name}"

            expect do
              update_user_as_self(user, name: new_name)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq(expected_message)
          end
        end

        context 'updating projects_limit' do
          let(:new_projects_limit) { 20 }
          let(:expected_message) { "Changed projects limit from #{Gitlab::CurrentSettings.default_projects_limit} to #{new_projects_limit}" }

          let_it_be_with_reload(:admin_user) { create(:admin) }

          it 'logs audit event' do
            expect do
              update_user_as(admin_user, user, projects_limit: new_projects_limit)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq(expected_message)
          end
        end

        context 'updating can_create_group' do
          let(:expected_message) { 'Changed can create group from true to false' }

          let_it_be_with_reload(:admin_user) { create(:admin) }

          it 'logs audit event' do
            expect do
              update_user_as(admin_user, user, can_create_group: false)
            end.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last.present.action).to eq(expected_message)
          end
        end

        context 'audit event entity scoping' do
          let_it_be_with_reload(:admin_user) { create(:admin) }
          let_it_be(:group_owner) { create(:user) }
          let_it_be(:enterprise_group) { create(:group, owners: group_owner) }
          let_it_be(:enterprise_group_verified_domain) { create(:pages_domain, project: create(:project, group: enterprise_group)) }
          let_it_be_with_reload(:enterprise_user) { create(:enterprise_user, enterprise_group: enterprise_group) }

          where(:attribute, :updated_value, :event_name) do
            :email            | lazy { "new-email@#{enterprise_group_verified_domain.domain}" } | 'user_email_address_updated'
            :password         | 'new_password'                                                  | 'user_password_updated'
            :username         | 'new_username'                                                  | 'user_username_updated'
            :name             | 'new_name'                                                      | 'user_name_updated'
            :admin            | true                                                            | 'user_admin_status_updated'
            :auditor          | true                                                            | 'user_auditor_status_updated'
            :external         | true                                                            | 'user_external_status_updated'
            :projects_limit   | lazy { (Gitlab::CurrentSettings.default_projects_limit + 10) }  | 'user_projects_limit_updated'
            :can_create_group | false                                                           | 'user_can_create_group_updated'
          end

          with_them do
            before do
              stub_application_setting(admin_mode: false)
            end

            context 'when target user is an enterprise user', :saas do
              before do
                stub_licensed_features(domain_verification: true)

                enterprise_user.skip_reconfirmation! if attribute == :email
              end

              it 'scopes audit events to the enterprise group when an admin makes the change', :aggregate_failures do
                last_id = AuditEventReader.maximum(:id).to_i
                update_user_as(admin_user, enterprise_user, attribute => updated_value)

                event = AuditEvents::GroupAuditEvent.where('id > ?', last_id)
                  .where(group_id: enterprise_group.id)
                  .find { |e| e.details[:event_name] == event_name }

                expect(event).not_to be_nil
                expect(event.author).to eq(admin_user)
              end

              it 'scopes audit events to the enterprise group when a group owner makes the change', :aggregate_failures do
                last_id = AuditEventReader.maximum(:id).to_i
                update_user_as(group_owner, enterprise_user, attribute => updated_value, force_name_change: true)

                event = AuditEvents::GroupAuditEvent.where('id > ?', last_id)
                  .where(group_id: enterprise_group.id)
                  .find { |e| e.details[:event_name] == event_name }

                expect(event).not_to be_nil
                expect(event.author).to eq(group_owner)
              end

              it 'scopes audit events to the enterprise group when the user makes the change', :aggregate_failures do
                last_id = AuditEventReader.maximum(:id).to_i
                update_user_as_self(enterprise_user, attribute => updated_value, force_name_change: true)

                event = AuditEvents::GroupAuditEvent.where('id > ?', last_id)
                  .where(group_id: enterprise_group.id)
                  .find { |e| e.details[:event_name] == event_name }

                expect(event).not_to be_nil
                expect(event.author).to eq(enterprise_user)
              end
            end

            context 'when target user is not an enterprise user' do
              before do
                user.skip_reconfirmation! if attribute == :email
              end

              it 'scopes audit events to the user when an admin makes the change', :aggregate_failures do
                last_id = AuditEventReader.maximum(:id).to_i
                update_user_as(admin_user, user, attribute => updated_value)

                event = AuditEvents::UserAuditEvent.where('id > ?', last_id)
                  .where(user_id: user.id)
                  .find { |e| e.details[:event_name] == event_name }

                expect(event).not_to be_nil
                expect(event.author).to eq(admin_user)
              end

              it 'scopes audit events to the user when the user makes the change', :aggregate_failures do
                last_id = AuditEventReader.maximum(:id).to_i
                update_user_as_self(user, attribute => updated_value, force_name_change: true)

                event = AuditEvents::UserAuditEvent.where('id > ?', last_id)
                  .where(user_id: user.id)
                  .find { |e| e.details[:event_name] == event_name }

                expect(event).not_to be_nil
                expect(event.author).to eq(user)
              end
            end
          end
        end
      end
    end

    it 'does not update email if an user has group managed account' do
      allow(user).to receive(:group_managed_account?).and_return(true)

      expect do
        update_user_as_self(user, { email: 'foreign@email' })
      end.not_to change { user.reload.email }
    end

    it 'does not update commit email if an user has group managed account' do
      allow(user).to receive(:group_managed_account?).and_return(true)

      expect do
        update_user_as_self(user, { commit_email: 'foreign@email' })
      end.not_to change { user.reload.commit_email }
    end

    it 'does not update public email if an user has group managed account' do
      allow(user).to receive(:group_managed_account?).and_return(true)

      expect do
        update_user_as_self(user, { public_email: 'foreign@email' })
      end.not_to change { user.reload.public_email }
    end

    it 'does not update notification email if an user has group managed account' do
      allow(user).to receive(:group_managed_account?).and_return(true)

      expect do
        update_user_as_self(user, { notification_email: 'foreign@email' })
      end.not_to change { user.reload.notification_email }
    end

    context 'with an admin user' do
      let_it_be_with_reload(:admin_user) { create(:admin) }

      let(:service) { described_class.new(admin_user, ActionController::Parameters.new(params).permit!) }
      let(:params) do
        { name: 'John Doe', username: 'jduser', email: 'jd@example.com', password: User.random_password }
      end

      context 'allowed params' do
        context 'with identity' do
          let(:provider) { create(:saml_provider) }
          let(:identity_params) { { extern_uid: 'uid', provider: 'group_saml', group_id_for_saml: provider.group.id } }

          before do
            params.merge!(identity_params)
          end

          it 'adds identity to user' do
            result = update_user_as_self(user, params)

            expect(result).to be true
            expect(user.identities.last.saml_provider_id).to eq(provider.id)
            expect(user.identities.last.extern_uid).to eq('uid')
            expect(user.identities.last.provider).to eq('group_saml')
          end

          it 'adds two different identities to user' do
            second_provider = create(:saml_provider)
            result_one = update_user_as_self(user, { extern_uid: 'uid', provider: 'group_saml', saml_provider_id: provider.id })
            result_two = update_user_as_self(user, { extern_uid: 'uid2', provider: 'group_saml', group_id_for_saml: second_provider.group.id })

            expect(result_one).to be true
            expect(result_two).to be true
            expect(user.identities.count).to eq(2)
            expect(user.identities.map(&:extern_uid)).to match_array(%w[uid uid2])
            expect(user.identities.map(&:saml_provider_id)).to match_array([provider.id, second_provider.id])
          end
        end
      end
    end

    context 'updating private_profile' do
      let(:admin) { create(:admin) }

      shared_examples_for 'a user can make their profile private' do
        it 'makes the profile private' do
          result = update_user_as(current_user, user, { user: user, private_profile: true })

          expect(result).to be_truthy
          expect(user.private_profile).to be true
        end
      end

      context 'when `disable_private_profiles` feature is available' do
        before do
          stub_licensed_features(disable_private_profiles: true)
        end

        context 'when the ability to make their profiles private is not disabled for users' do
          before do
            stub_application_setting(make_profile_private: true)
          end

          it_behaves_like 'a user can make their profile private' do
            let(:current_user) { user }
          end
        end

        context 'when the ability to make their profiles private is disabled for users' do
          before do
            stub_application_setting(make_profile_private: false)
          end

          context 'when the profile is public' do
            context 'as a regular user' do
              let(:current_user) { user }

              it 'does not make the profile private' do
                result = update_user_as(current_user, user, { user: user, private_profile: true })

                expect(result).to be_truthy
                expect(user.private_profile).not_to be true
              end
            end
          end
        end

        context 'when the profile is private' do
          let(:current_user) { user }

          before do
            current_user.update!(private_profile: true)
          end

          it 'makes the profile public' do
            result = update_user_as(current_user, user, { user: user, private_profile: false })

            expect(result).to be_truthy
            expect(user.private_profile).not_to be true
          end
        end
      end

      context 'when `disable_private_profiles` feature is not available' do
        before do
          stub_application_setting(make_profile_private: false)
          stub_licensed_features(disable_private_profiles: false)
        end

        it_behaves_like 'a user can make their profile private' do
          let(:current_user) { user }
        end
      end
    end

    def update_user_as(current_user, user, opts)
      described_class.new(current_user, opts.merge(user: user)).execute!
    end

    def update_user_as_self(user, opts)
      update_user_as(user, user, opts)
    end
  end

  describe '#execute', :saas do
    context 'updating email' do
      context 'if email was changed' do
        context 'when check_password is true' do
          def update_user(user, opts)
            described_class.new(user, opts.merge(user: user)).execute(check_password: true)
          end

          context 'when password authentication is disabled by enterprise group' do
            before do
              stub_licensed_features(domain_verification: true)
            end

            let_it_be(:enterprise_group) { create(:group) }
            let_it_be(:saml_provider) do
              create(
                :saml_provider,
                group: enterprise_group,
                enabled: true,
                disable_password_authentication_for_enterprise_users: true
              )
            end

            let_it_be(:project) { create(:project, group: enterprise_group) }
            let_it_be(:verified_domain) { create(:pages_domain, project: project) }
            let_it_be(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

            it 'does not require password for enterprise users', :aggregate_failures do
              result = {}

              expect do
                result = update_user(user, { email: "example@#{verified_domain.domain}" })
              end.to change { user.reload.unconfirmed_email }
              expect(result[:status]).to eq(:success)
            end
          end
        end
      end
    end
  end
end
