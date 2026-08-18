# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::BuildService, feature_category: :user_management do
  describe '#execute' do
    let(:params) do
      { name: 'John Doe', username: 'jduser', email: 'jd@example.com', password: 'mydummypass' }
    end

    context 'with an admin user' do
      let_it_be(:admin_user) { create(:admin) }

      let(:service) { described_class.new(admin_user, ActionController::Parameters.new(params).permit!) }

      context 'with identity' do
        let_it_be(:provider) { create(:saml_provider) }
        let(:identity_params) { { extern_uid: 'uid', provider: 'group_saml', saml_provider_id: provider.id } }

        before do
          params.merge!(identity_params)
        end

        it 'sets all allowed attributes' do
          expect(Identity).to receive(:new).with(hash_including(identity_params)).and_call_original
          expect(GroupScimIdentity).not_to receive(:new)

          service.execute
        end

        context 'with scim identity' do
          let_it_be(:group) { create(:group) }
          let_it_be(:scim_identity_params) { { extern_uid: 'uid', provider: 'group_scim', group_id: group.id } }

          before do
            params.merge!(scim_identity_params)
          end

          it 'passes allowed attributes to both scim and saml identity' do
            scim_params = scim_identity_params.dup
            scim_params.delete(:provider)

            expect(GroupScimIdentity).to receive(:new).with(hash_including(scim_params)).and_call_original
            expect(Identity).to receive(:new).with(hash_including(identity_params)).and_call_original

            service.execute
          end

          it 'marks the user as provisioned by group' do
            expect(service.execute.provisioned_by_group_id).to eq(group.id)
          end

          context 'with project_id param' do
            let_it_be(:project) { create(:project) }

            before do
              params.merge!(project_id: project.id)
            end

            it 'marks the user as provisioned by project' do
              expect(service.execute.provisioned_by_project_id).to eq(project.id)
            end
          end
        end
      end

      context 'with auditor as allowed params' do
        let(:params) { super().merge(auditor: 1) }

        it 'sets auditor to true' do
          user = service.execute

          expect(user.auditor).to eq(true)
        end
      end

      context 'with composite_identity_enforced as allowed params' do
        let(:params) { super().merge(composite_identity_enforced: true) }

        it 'sets composite_identity_enforced to true' do
          user = service.execute

          expect(user.composite_identity_enforced).to eq(true)
        end
      end

      context 'with provisioned by group param' do
        let(:group) { create(:group) }
        let(:params) { super().merge(provisioned_by_group_id: group.id) }

        it 'does not set provisioned by group' do
          user = service.execute

          expect(user.provisioned_by_group_id).to eq(nil)
        end

        context 'with service account user type' do
          before do
            params.merge!(user_type: 'service_account')
          end

          it 'allows provisioned by group id to be set' do
            user = service.execute

            expect(user.provisioned_by_group_id).to eq(group.id)
            expect(user.user_type).to eq('service_account')
          end
        end
      end

      context 'with provisioned by project param' do
        let(:project) { build_stubbed(:project) }
        let(:params) { super().merge(provisioned_by_project_id: project.id) }

        it 'does not set provisioned by project' do
          user = service.execute

          expect(user.provisioned_by_project_id).to eq(nil)
        end

        context 'with service account user type' do
          before do
            params.merge!(user_type: 'service_account')
          end

          it 'allows provisioned by project id to be set' do
            user = service.execute

            expect(user.provisioned_by_project_id).to eq(project.id)
            expect(user.user_type).to eq('service_account')
          end
        end
      end

      context 'smartcard authentication enabled' do
        before do
          allow(Gitlab::Auth::Smartcard).to receive(:enabled?).and_return(true)
        end

        context 'smartcard params' do
          let(:subject) { '/O=Random Corp Ltd/CN=gitlab-user/emailAddress=gitlab-user@random-corp.org' }
          let(:issuer) { '/O=Random Corp Ltd/CN=Random Corp' }
          let(:smartcard_identity_params) do
            { certificate_subject: subject, certificate_issuer: issuer }
          end

          before do
            params.merge!(smartcard_identity_params)
          end

          it 'sets smartcard identity attributes' do
            expect(SmartcardIdentity).to(
              receive(:new)
                .with(hash_including(issuer: issuer, subject: subject))
                .and_call_original)

            service.execute
          end
        end

        context 'missing smartcard params' do
          it 'works as expected' do
            expect { service.execute }.not_to raise_error
          end
        end
      end

      context 'user signup cap' do
        context 'when user signup cap is set' do
          before do
            allow(Gitlab::CurrentSettings).to receive(:new_user_signups_cap).and_return(3)
            stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_USER_CAP)
          end

          context 'when new user signup exceeds user cap' do
            let!(:users) { create_list(:user, 2) }

            it 'sets the user state to blocked_pending_approval' do
              user = service.execute

              expect(user).to be_blocked_pending_approval
            end
          end

          context 'when new user signup does not exceed user cap' do
            let!(:users) { create_list(:user, 1) }

            it 'sets the user state to active' do
              user = service.execute

              expect(user).to be_active
            end
          end

          context 'when new bot user exceeds user cap' do
            let!(:users) { create_list(:user, 2) }

            before do
              params.merge!({ user_type: :project_bot })
            end

            it 'sets the bot user state to active' do
              user = service.execute

              expect(user).to be_active
            end
          end

          context 'with an ultimate license' do
            let_it_be(:group) { create(:group) }
            let_it_be(:billable_users) { create_list(:user, 3) }

            before_all do
              billable_users.each { |u| group.add_developer(u) }
            end

            before do
              license = create(:license, plan: License::ULTIMATE_PLAN)
              allow(License).to receive(:current).and_return(license)
            end

            it 'sets a new billable user state to blocked pending approval' do
              member = create(:group_member, :developer, :invited)
              params.merge!(email: member.invite_email, skip_confirmation: true)

              user = service.execute

              expect(user).to be_blocked_pending_approval
            end

            it 'sets a new non-billable user state to active' do
              user = service.execute

              expect(user).to be_active
            end

            context 'when the feature flag is disabled' do
              before do
                stub_feature_flags(activate_nonbillable_users_over_instance_user_cap: false)
              end

              it 'sets a new billable user state to blocked pending approval' do
                member = create(:group_member, :developer, :invited)
                params.merge!(email: member.invite_email, skip_confirmation: true)

                user = service.execute

                expect(user).to be_blocked_pending_approval
              end

              it 'sets a new non-billable user state to blocked pending approval' do
                user = service.execute

                expect(user).to be_blocked_pending_approval
              end
            end
          end
        end

        context 'when user signup cap is not set' do
          it 'sets the user state to active' do
            user = service.execute

            expect(user).to be_active
          end
        end
      end
    end

    context 'with a non-admin user' do
      let(:service) { described_class.new(nil, ActionController::Parameters.new(params).permit!) }

      before do
        allow(Gitlab::CurrentSettings).to receive(:allow_signup?).and_return(true)
      end

      context 'with service account user type' do
        before do
          params.merge!(user_type: 'service_account')
        end

        context 'with avatar param' do
          let(:avatar_file) { fixture_file_upload('spec/fixtures/avatars/avatar1.png') }

          before do
            params.merge!(avatar: avatar_file)
          end

          it 'accepts avatar param for service account' do
            user = service.execute

            expect(user.avatar_url).to include('avatar1.png')
          end
        end
      end

      context 'without service account user type' do
        context 'with avatar param' do
          let(:avatar_file) { fixture_file_upload('spec/fixtures/avatars/avatar1.png') }

          before do
            params.merge!(avatar: avatar_file)
          end

          it 'does not accept avatar param for non-service account' do
            user = service.execute

            expect(user.avatar_url).not_to include('avatar1.png')
          end
        end
      end
    end
  end
end
