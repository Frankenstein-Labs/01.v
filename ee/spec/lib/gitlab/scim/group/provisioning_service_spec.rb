# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Scim::Group::ProvisioningService, :saas,
  feature_category: :system_access do
  describe '#execute' do
    let(:group) { create(:group) }
    let_it_be(:service_params) do
      {
        email: 'work@example.com',
        name: 'Test Name',
        extern_uid: 'test_uid',
        username: 'username'
      }
    end

    let(:service) { described_class.new(service_params, group) }
    let(:enforced_sso) { false }
    let!(:saml_provider) do
      create(:saml_provider, group: group,
        enforced_sso: enforced_sso,
        default_membership_role: Gitlab::Access::DEVELOPER)
    end

    before do
      stub_licensed_features(group_saml: true)
    end

    shared_examples 'success response' do
      it 'contains a success status' do
        expect(service.execute.status).to eq(:success)
      end

      it 'contains an identity in the response' do
        expect(service.execute.identity).to be_a(Identity).or be_a(GroupScimIdentity)
      end
    end

    shared_examples 'existing user' do
      it 'does not create a new user' do
        expect { service.execute }.not_to change { User.count }
      end

      it_behaves_like 'success response'

      it 'creates the SCIM identity' do
        expect { service.execute }.to change { GroupScimIdentity.count }.by(1)
      end

      it 'does not create the SAML identity' do
        expect { service.execute }.not_to change { Identity.count }
      end

      it 'does not log user_provisioned_by_scim audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including({
          name: "user_provisioned_by_scim"
        })).and_call_original

        service.execute
      end
    end

    context 'when valid params' do
      before do
        # By default SAAS version setting is hard as per docs
        # https://docs.gitlab.com/ee/user/gitlab_com/#email-confirmation
        stub_application_setting_enum('email_confirmation_setting', 'hard')
      end

      def user
        User.find_by(email: service_params[:email])
      end

      it_behaves_like 'success response'

      it 'creates the user' do
        expect { service.execute }.to change { User.count }.by(1)
      end

      it 'creates the group member' do
        expect { service.execute }.to change { GroupMember.count }.by(1)
      end

      it 'creates the correct user attributes' do
        service.execute

        expect(user).to be_a(User)
        expect(user.namespace.organization_id).to eq(group.organization_id)
      end

      context 'when access level is given for created group member' do
        let!(:saml_provider) do
          create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER)
        end

        it 'sets the access level of the member as specified in saml_provider' do
          service.execute

          access_level = group.member(user).access_level

          expect(access_level).to eq(Gitlab::Access::DEVELOPER)
        end
      end

      context 'when a custom role is given for created group member', feature_category: :permissions do
        let(:member_role) { create(:member_role, namespace: group) }
        let!(:saml_provider) do
          create(:saml_provider, group: group,
            default_membership_role: member_role.base_access_level,
            member_role: member_role)
        end

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'sets the `member_role` of the member as specified in `saml_provider`' do
          service.execute

          expect(group.member(user).member_role).to eq(member_role)
        end
      end

      it 'user record requires confirmation' do
        service.execute

        expect(user).to be_present
        expect(user).not_to be_confirmed
      end

      context 'when the current minimum password length is different from the default minimum password length' do
        before do
          stub_application_setting minimum_password_length: 21
        end

        it 'creates the user' do
          expect { service.execute }.to change { User.count }.by(1)
        end
      end

      context 'when a verified pages domain matches the user email domain' do
        before do
          stub_licensed_features(domain_verification: true)
          create(:pages_domain, project: create(:project, group: group), domain: 'example.com')
        end

        it 'creates a confirmed user' do
          service.execute

          expect(user).to be_present
          expect(user).to be_confirmed
        end
      end

      context 'when username contains special characters' do
        subject(:result) { service.execute }

        let_it_be(:service_params) do
          {
            email: 'work@example.com',
            name: 'Test Name',
            extern_uid: 'test_uid',
            username: ' --ricky.^#!__the._raccoon--'
          }
        end

        it 'sanitizes more special characters from the username' do
          expect { result }.to change { User.count }.by(1)
          expect(user.username).to eq('ricky.the.raccoon')
        end

        context 'and there is an existing user with the sanitized username' do
          before do
            create(:user, :with_namespace, username: 'ricky.the.raccoon')
          end

          it 'creates new user with non-conflicting username' do
            expect { result }.to change { User.count }.by(1)
            expect(user.username).to eq('ricky.the.raccoon1')
          end
        end
      end

      context 'with BSO (Block Seat Overages) enabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: true)
          stub_licensed_features(minimal_access_role: true)
        end

        context 'without available seats' do
          before do
            allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to receive_messages(
                block_seat_overages?: true,
                seats_available_for?: false
              )
          end

          it 'creates user with MINIMAL_ACCESS instead of the desired access level' do
            service.execute

            member = group.all_group_members.find_by(user: user)
            expect(member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
          end

          it 'logs BSO adjustment when access level is downgraded' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                message: 'Group membership access level adjusted due to BSO seat limits',
                group_id: group.id,
                group_path: group.full_path,
                user_id: be_a(Integer),
                requested_access_level: Gitlab::Access::DEVELOPER,
                adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                feature_flag: 'bso_minimal_access_fallback'
              )
            )

            service.execute
          end

          it 'tracks minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
            service.execute

            ::Gitlab::Redis::SharedState.with do |redis|
              current_date = Date.current.iso8601
              users_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
              root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

              expect(redis.sismember(users_key, user.id.to_s)).to be true
              expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be true
            end
          end

          it 'audits minimal access role adjustment' do
            service.execute

            audit_event = AuditEventReader.find_by(target_id: user.id)
            identity = group.scim_identities.find_by(user: user)

            expect(audit_event.entity).to eq(group)
            expect(audit_event.details[:user_id]).to eq(user.id)
            expect(audit_event.details[:requested_access_level]).to eq(Gitlab::Access::DEVELOPER)
            expect(audit_event.details[:scim_identity_id]).to eq(identity.id)
          end
        end

        context 'with available seats' do
          before do
            allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to receive_messages(
                block_seat_overages?: true,
                seats_available_for?: true
              )
          end

          it 'creates user with the original desired access level' do
            service.execute

            member = group.all_group_members.find_by(user: user)
            expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end

          it 'does not log BSO adjustment' do
            expect(Gitlab::AppLogger).not_to receive(:info).with(
              hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
            )

            service.execute
          end

          it 'does not track minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
            service.execute

            ::Gitlab::Redis::SharedState.with do |redis|
              current_date = Date.current.iso8601
              users_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
              root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

              expect(redis.sismember(users_key, user.id.to_s)).to be false
              expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be false
            end
          end
        end
      end

      context 'for audit' do
        let(:author) { ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)') }

        before do
          stub_licensed_features(extended_audit_events: true)
        end

        it 'logs user_provisioned_by_scim audit event' do
          expect { service.execute }.to change { AuditEventReader.count }.by(1)

          expect(AuditEventReader.last).to have_attributes({
            entity_id: group.id,
            entity_type: "Group",
            attributes: hash_including({
              "author_id" => author.id,
              "target_details" => user.username,
              "target_id" => user.id
            }),
            details: hash_including({
              event_name: "user_provisioned_by_scim",
              author_class: author.class.to_s,
              author_name: author.name,
              custom_message: "User was provisioned by SCIM",
              target_type: "User",
              target_details: user.username
            })
          })
        end
      end
    end

    context 'when a provisioning error occurs' do
      let(:result) { StandardError.new("testing error") }
      let(:log_params) do
        {
          error: result.class.name,
          message: "testing error"
        }
      end

      let(:logger) { described_class.new(service_params, group).send(:logger) }

      before do
        allow(service).to receive(:logger).and_return(logger)
      end

      it 'logs error to standard error' do
        allow(service).to receive(:create_user_and_member).and_raise(result)
        expect(logger).to receive(:error).with(hash_including(log_params))

        service.execute
      end
    end

    context 'when invalid params' do
      let_it_be(:service_params) do
        {
          email: 'work@example.com',
          name: 'Test Name',
          extern_uid: 'test_uid'
        }
      end

      it 'fails with error' do
        expect(service.execute.status).to eq(:error)
      end

      it 'fails with missing params' do
        expect(service.execute.message).to eq("Missing params: [:username]")
      end
    end

    it 'creates the SCIM identity' do
      expect { service.execute }.to change { GroupScimIdentity.count }.by(1)
    end

    it 'creates the SAML identity' do
      expect { service.execute }.to change { Identity.count }.by(1)
    end

    context 'for an existing user' do
      before do
        create(:email, :confirmed, user: user, email: 'work@example.com')
      end

      let(:user) { create(:user) }

      context 'when user is not a group member' do
        it_behaves_like 'existing user'

        it 'creates the group member' do
          expect { service.execute }.to change { GroupMember.count }.by(1)
        end

        context 'with enforced SSO' do
          let(:enforced_sso) { true }

          it 'does not create the group member' do
            expect { service.execute }.not_to change { GroupMember.count }
          end

          it 'does not create the SAML identity' do
            expect { service.execute }.not_to change { Identity.count }
          end

          it 'does not create the SCIM identity' do
            expect { service.execute }.not_to change { GroupScimIdentity.count }
          end
        end
      end

      context 'when user is an existing group member' do
        before do
          group.add_guest(user)
        end

        it_behaves_like 'existing user'

        it 'does not create the group member' do
          expect { service.execute }.not_to change { GroupMember.count }
        end

        context 'when invalid identity' do
          let_it_be(:service_params) do
            {
              email: 'work@example.com',
              name: 'Test Name',
              extern_uid: '',
              username: 'username'
            }
          end

          let(:provision_response) do
            ::Gitlab::Scim::ProvisioningResponse.new(identity: nil,
              status: :error,
              message: "Extern uid can't be blank")
          end

          it 'does not return nil result' do
            expect(service.execute).not_to be_nil
          end

          it 'returns error response' do
            expect(service.execute.to_json).to eq(provision_response.to_json)
          end
        end

        context 'when saving the identity fails' do
          before do
            allow_next_instance_of(GroupScimIdentity) do |instance|
              allow(instance).to receive(:save).and_return(false)
              instance.errors.add(:base, 'Some error happened')
            end
          end

          it 'returns provision response error' do
            response = service.execute

            expect(response).to be_a(::Gitlab::Scim::ProvisioningResponse)
            expect(response.as_json).to match(hash_including('status' => 'error',
              'message' => 'Some error happened',
              'identity' => nil))
          end
        end
      end

      context 'when the user is pending deprovision' do
        let(:pending_deprovisioning_message) do
          'User is pending deprovisioning. Please wait for the user to be deprovisioned and try again later.'
        end

        before do
          group.add_reporter(user)
          create(:members_deletion_schedules, user: user, namespace: group)
        end

        context 'when the user has a scim identity' do
          before do
            create(:group_scim_identity, user: user, group: group, extern_uid: 'test_uid', active: false)
          end

          it 'returns an error' do
            response = service.execute

            expect(response.as_json).to match(hash_including('status' => 'conflict',
              'message' => pending_deprovisioning_message,
              'identity' => nil))
          end
        end

        context 'when the user does not have a scim identity' do
          it 'returns an error' do
            response = service.execute

            expect(response.as_json).to match(hash_including('status' => 'conflict',
              'message' => pending_deprovisioning_message,
              'identity' => nil))
          end
        end

        context 'when the extern_uid and email identify different users' do
          let_it_be(:service_params) do
            {
              email: 'other_work@example.com',
              name: 'Test Name',
              extern_uid: 'test_uid',
              username: 'username'
            }
          end

          before do
            create(:group_scim_identity, user: user, group: group, extern_uid: 'test_uid', active: false)

            other_user = create(:user)
            create(:email, :confirmed, user: other_user, email: 'other_work@example.com')
          end

          it 'returns an error' do
            response = service.execute

            expect(response.as_json).to match(hash_including('status' => 'conflict',
              'message' => pending_deprovisioning_message,
              'identity' => nil))
          end
        end
      end
    end
  end
end
