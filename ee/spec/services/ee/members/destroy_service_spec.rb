# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::DestroyService, feature_category: :groups_and_projects do
  let_it_be(:group) { create(:group) }
  let_it_be(:admin_bot) { create(:user, :admin_bot) }

  let(:current_user) { create(:user) }
  let(:member_user) { create(:user) }
  let(:member) { group.members.find_by(user_id: member_user.id) }
  let(:member_role) { nil }

  before do
    group.add_owner(current_user)
    group.add_developer(member_user)
  end

  shared_examples_for 'logs an audit event' do
    specify do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: "member_destroyed",
          additional_details: hash_including(
            remove: "user_access",
            member_role_id: member_role&.id
          )
        )
      ).and_call_original

      expect { event }.to change { AuditEventReader.count }.by(1)
    end
  end

  context 'when current_user is present' do
    context 'with group membership via Group SAML' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group) }

      context 'with a SAML identity' do
        before do
          create(:group_saml_identity, user: member_user, saml_provider: saml_provider)
        end

        context 'when skip_saml_identity is true' do
          it 'preserves linked SAML identity' do
            expect { described_class.new(member, current_user: current_user, skip_saml_identity: true).execute }
              .to not_change { member_user.reload.identities.count }
          end
        end
      end

      context 'without a SAML identity' do
        it 'does not attempt to destroy unrelated identities' do
          create(:identity, user: member_user)

          expect { described_class.new(member, current_user: current_user).execute }.not_to change { Identity.count }
        end
      end
    end

    context 'audit events' do
      it_behaves_like 'logs an audit event' do
        let(:event) { described_class.new(member, current_user: current_user).execute }
      end

      it 'does not log the audit event as a system event' do
        described_class.new(member, current_user: current_user, skip_authorization: true).execute
        details = AuditEventReader.last.details

        expect(details[:system_event]).to be_nil
        expect(details[:reason]).to be_nil
      end
    end

    context 'streaming audit event' do
      subject(:destroy_service) { described_class.new(member, current_user: current_user, skip_authorization: true).execute }

      it 'audits event with name' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: "member_destroyed", additional_details: hash_including(as: "Default role: Developer"))
        ).and_call_original

        destroy_service
      end

      include_examples 'sends streaming audit event'
    end

    context 'on-call rotations' do
      let_it_be(:project) { create(:project, group: group) }

      context 'when member is in an on-call rotation' do
        let(:project_1_schedule) {  create(:incident_management_oncall_schedule, project: project) }
        let(:project_1_rotation) {  create(:incident_management_oncall_rotation, schedule: project_1_schedule) }
        let!(:project_1_participant) { create(:incident_management_oncall_participant, rotation: project_1_rotation, user: member_user) }

        let(:project_2) { create(:project, group: group) }
        let(:project_2_schedule) {  create(:incident_management_oncall_schedule, project: project_2) }
        let(:project_2_rotation) {  create(:incident_management_oncall_rotation, schedule: project_2_schedule) }
        let!(:project_2_participant) { create(:incident_management_oncall_participant, rotation: project_2_rotation, user: member_user) }

        context 'when group member is removed' do
          it 'calls the remove service for each project in the group' do
            expect(IncidentManagement::OncallRotations::RemoveParticipantsService).to receive(:new).with([project_1_rotation, project_2_rotation], member_user).and_call_original

            described_class.new(member, current_user: current_user).execute

            expect(project_1_participant.reload.is_removed).to eq(true)
            expect(project_2_participant.reload.is_removed).to eq(true)
          end
        end

        context 'when project member is removed' do
          let!(:project_member) { create(:project_member, source: project, user: member_user) }

          it 'calls the remove service for that project only' do
            expect(IncidentManagement::OncallRotations::RemoveParticipantsService).to receive(:new).with([project_1_rotation], member_user).and_call_original

            described_class.new(project_member, current_user: current_user).execute

            expect(project_1_participant.reload.is_removed).to eq(true)
            expect(project_2_participant.reload.is_removed).to eq(false)
          end
        end
      end

      context 'when member is not part of an on-call rotation for the group' do
        before do
          # Creates a rotation for another project in another group
          create(:incident_management_oncall_participant, user: member_user)
        end

        it 'does not call the remove service' do
          expect(IncidentManagement::OncallRotations::RemoveParticipantsService).not_to receive(:new)

          described_class.new(member, current_user: current_user).execute
        end
      end
    end

    context 'user escalation rules' do
      let(:project) { create(:project, group: group) }
      let(:project_2) { create(:project, group: group) }
      let(:project_1_policy) { create(:incident_management_escalation_policy, project: project) }
      let(:project_2_policy) { create(:incident_management_escalation_policy, project: project_2) }
      let!(:project_1_rule) { create(:incident_management_escalation_rule, :with_user, user: member_user, policy: project_1_policy) }
      let!(:project_2_rule) { create(:incident_management_escalation_rule, :with_user, user: member_user, policy: project_2_policy) }

      shared_examples_for 'calls the destroy service' do |scope, *rules|
        let(:rules_to_delete) { rules.map { |rule_name| send(rule_name) } }
        let(:rules_to_preserve) { IncidentManagement::EscalationRule.all - rules_to_delete }

        it "calls the destroy service #{scope}" do
          expect(IncidentManagement::EscalationRules::DestroyService)
            .to receive(:new)
            .with({ escalation_rules: rules_to_delete, user: member_user })
            .and_call_original

          described_class.new(member, current_user: current_user).execute

          rules_to_delete.each { |rule| expect { rule.reload }.to raise_error(ActiveRecord::RecordNotFound) }
          rules_to_preserve.each { |rule| expect { rule.reload }.not_to raise_error }
        end
      end

      context 'group member is removed' do
        let(:other_user) { create(:user, developer_of: group) }
        let!(:other_user_rule) { create(:incident_management_escalation_rule, :with_user, user: other_user, policy: project_1_policy) }
        let!(:other_namespace_rule) { create(:incident_management_escalation_rule, :with_user, user: member_user) }

        include_examples 'calls the destroy service', 'with rules each project in the group', :project_1_rule, :project_2_rule
      end

      context 'project member is removed' do
        let!(:member) { create(:project_member, source: project, user: member_user) }

        include_examples 'calls the destroy service', 'with rules for the project', :project_1_rule
      end
    end

    context 'when user has associated protected branch rules' do
      let_it_be(:project) { create(:project) }

      let(:worker_class) { ::MembersDestroyer::CleanUpGroupProtectedBranchRulesWorker }

      context 'when member source is a project' do
        let(:member) { create(:project_member, project: project, user: member_user) }

        it 'does not enqueues the CleanUpGroupProtectedBranchRulesWorker' do
          expect(worker_class).not_to receive(:perform_async)

          described_class.new(member, current_user: current_user, skip_authorization: true).execute
        end
      end

      context 'when member source is a group' do
        subject do
          described_class.new(member, current_user: current_user, skip_authorization: true).execute
        end

        it 'enqueues the CleanUpGroupProtectedBranchRulesWorker' do
          expect(worker_class).to receive(:perform_async).with(group.id, member_user.id).and_call_original

          subject
        end
      end
    end

    context 'when user is a security_policy_bot' do
      let_it_be(:project) { create(:project) }
      let_it_be(:user) { create(:user, user_type: :security_policy_bot) }
      let_it_be(:member) { create(:project_member, user: user, project: project) }
      let_it_be(:security_orchestration_policy_configuration) { create(:security_orchestration_policy_configuration) }

      before do
        project.add_owner(current_user)
      end

      it 'denies access' do
        expect { described_class.new(member, current_user: current_user).execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when destroying member related data' do
      context 'when AI features are available' do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'clears AI access cache' do
          expect(User).to receive(:clear_group_with_ai_available_cache).with(member_user.id)

          described_class.new(member, current_user: current_user).execute
        end
      end

      context 'when AI features are not available' do
        before do
          stub_licensed_features(ai_features: false)
        end

        it 'does not clear the AI access cache' do
          expect(User).not_to receive(:clear_group_with_ai_available_cache)

          described_class.new(member, current_user: current_user).execute
        end
      end
    end

    context 'user add-on seat assignments' do
      let(:worker_class) { GitlabSubscriptions::AddOnPurchases::CleanupUserAddOnAssignmentWorker }

      context 'when on self managed' do
        it 'does not enqueue CleanupUserAddOnAssignmentWorker' do
          expect(worker_class).not_to receive(:perform_async)

          described_class.new(member, current_user: current_user).execute
        end
      end

      context 'when on SaaS', :saas do
        it 'enqueues the CleanupUserAddOnAssignmentWorker with correct arguments' do
          expect(worker_class).to receive(:perform_async).with(group.id, member_user.id).and_call_original

          described_class.new(member, current_user: current_user).execute
        end

        context 'when project member is removed' do
          let!(:project_member) { create(:project_member, source: create(:project, group: group), user: member_user) }

          it 'enqueues the CleanupUserAddOnAssignmentWorker with correct arguments' do
            expect(worker_class).to receive(:perform_async).with(group.id, member_user.id).and_call_original

            described_class.new(project_member, current_user: current_user).execute
          end
        end

        context 'when recursive call is made to remove inherited membership' do
          let(:sub_group) { create(:group, parent: group) }
          let!(:sub_member) { create(:group_member, source: sub_group, user: member_user) }

          it 'enqueues the worker only once' do
            expect(Member.where(user: member_user).count).to eq(2)

            expect(worker_class).to receive(:perform_async).with(group.id, member_user.id).and_call_original

            expect do
              described_class.new(member, current_user: current_user).execute
            end.to change { Member.where(user: member_user).count }.by(-2)
          end
        end
      end
    end

    context 'when removing a service account group member' do
      subject(:destroy_service) { described_class.new(member, current_user: current_user).execute }

      let(:member_user) { create(:user, :service_account) }

      it 'removes the service account member' do
        expect { subject }.to change { member.source.members_and_requesters.count }.by(-1)
      end

      it 'does not label the audit event as duo_related without an enforced composite identity' do
        destroy_service

        expect(AuditEventReader.last.details).to include(event_name: 'member_destroyed').and exclude(:duo_related)
      end
    end

    context 'when removing a DAP service account member' do
      let(:member_user) { create(:user, :ai_service_account) }

      it 'labels the audit event as duo_related' do
        described_class.new(member, current_user: current_user).execute

        expect(AuditEventReader.last.details).to include(event_name: 'member_destroyed', duo_related: true)
      end
    end

    context 'when removing a non-DAP member' do
      it 'does not label the audit event as duo_related' do
        described_class.new(member, current_user: current_user).execute

        expect(AuditEventReader.last.details).to include(event_name: 'member_destroyed').and exclude(:duo_related)
      end
    end

    context 'when removing an invited member without a user' do
      let(:member) { create(:group_member, :invited, source: group) }

      it 'does not label the audit event as duo_related' do
        described_class.new(member, current_user: current_user).execute

        expect(AuditEventReader.last.details).to include(event_name: 'member_destroyed').and exclude(:duo_related)
      end
    end

    context 'with block seat overages' do
      it 'resets the all seats used banner callout', :sidekiq_inline do
        Users::GroupCallout.create!(group: group, user_id: current_user.id, feature_name: ::EE::Users::GroupCalloutsHelper::ALL_SEATS_USED_ALERT)

        described_class.new(member, current_user: current_user).execute

        expect(::Users::GroupCallout.count).to eq(0)
      end
    end

    describe "user's Authz::UserGroupMemberRole records" do
      let_it_be(:member_role) { create(:member_role, namespace: group) }

      shared_examples 'does not enqueue a DestroyForGroupWorker job' do
        specify do
          expect(::Authz::UserGroupMemberRoles::DestroyForGroupWorker).not_to receive(:perform_async)

          described_class.new(member, current_user: current_user).execute
        end
      end

      shared_examples 'enqueues a DestroyForGroupWorker job' do
        specify do
          expect(::Authz::UserGroupMemberRoles::DestroyForGroupWorker)
            .to receive(:perform_async).with(member.user_id, member.source_id)

          described_class.new(member, current_user: current_user).execute
        end
      end

      context 'when membership has a member role assigned' do
        before do
          member.update!(member_role: member_role)
        end

        it_behaves_like 'logs an audit event' do
          let(:event) { described_class.new(member, current_user: current_user).execute }
        end

        it_behaves_like 'enqueues a DestroyForGroupWorker job'

        context 'with project membership' do
          let_it_be(:project) { create(:project, group: group) }
          let(:member) { create(:project_member, :developer, user: member_user, project: project) }

          it_behaves_like 'does not enqueue a DestroyForGroupWorker job'
        end
      end

      context 'when membership has no member role assigned' do
        it_behaves_like 'does not enqueue a DestroyForGroupWorker job'

        context 'when Authz::UserGroupMemberRole records exists for the user through member.source' do
          before do
            create(:user_group_member_role, user: member.user, shared_with_group: member.source)
          end

          it_behaves_like 'enqueues a DestroyForGroupWorker job'
        end

        context 'when Authz::UserProjectMemberRole records exists for the user through member.source' do
          before do
            create(:user_project_member_role, user: member.user, shared_with_group: member.source)
          end

          it_behaves_like 'enqueues a DestroyForGroupWorker job'
        end
      end
    end
  end

  context 'when current user is not present' do # ie, when the system initiates the destroy
    context 'for members with expired access' do
      let!(:member) { create(:project_member, user: member_user, expires_at: 1.day.from_now) }
      let(:project) { member.project }

      before do
        travel_to(3.days.from_now)
      end

      context 'audit events' do
        it_behaves_like 'logs an audit event' do
          let(:event) { described_class.new(member, current_user: nil, skip_authorization: true).execute }
        end

        it 'logs the audit event as a system event' do
          described_class.new(member, current_user: nil, skip_authorization: true).execute
          details = AuditEventReader.last.details

          expect(details[:system_event]).to eq(true)
          expect(details[:reason]).to include('access expired on')
        end
      end

      context 'when member has outstanding not_accepted_invitations' do
        let(:event) { described_class.new(member, current_user: nil, skip_authorization: true).execute }
        let!(:invite) { create(:project_member, :invited, source: project, created_by: member_user) }

        it 'logs two audit events with no AuditEvents::BuildService::MissingAttributeError' do
          expect { event }.to change { AuditEventReader.count }.by(2)
        end
      end
    end

    context 'for members with non-expired access' do
      let!(:member) { create(:project_member, user: member_user) }

      context 'audit events' do
        it_behaves_like 'logs an audit event' do
          let(:event) { described_class.new(member, current_user: nil, skip_authorization: true).execute }
        end

        it 'logs the audit event as a system event' do
          described_class.new(member, current_user: nil, skip_authorization: true).execute
          details = AuditEventReader.last.details

          expect(details[:system_event]).to eq(true)
          expect(details[:author_name]).to eq('(System)')
          expect(details[:author_class]).to eq(Gitlab::Audit::UnauthenticatedAuthor.name)
          expect(details[:reason]).to eq('SCIM')
        end
      end

      context 'when member has outstanding not_accepted_invitations' do
        subject(:event) { described_class.new(member, current_user: nil, skip_authorization: true).execute }

        let!(:invite) { create(:project_member, :invited, source: project, created_by: member_user) }
        let(:project) { member.project }

        it 'logs two audit events with no AuditEvents::BuildService::MissingAttributeError' do
          expect { event }.to change { AuditEventReader.count }.by(2)
        end
      end
    end
  end

  context 'when current_user is the admin bot' do
    subject(:destroy_service) { described_class.new(member, current_user: admin_bot) }

    context 'audit events', :request_store do
      let(:request_ip_address) { '10.0.0.5' }
      let(:ip_address) { '172.16.3.3' }

      before do
        stub_licensed_features(admin_audit_log: true)
        allow(::Gitlab::RequestContext.instance).to receive(:client_ip).and_return(request_ip_address)
      end

      it 'records an audit event with the request ip address' do
        destroy_service.execute

        event = ::AuditEvents::GroupAuditEvent.last
        expect(event.ip_address).to eq(request_ip_address)
      end

      it 'records an audit event with the given ip_address when passed a parameter' do
        destroy_service = described_class.new(member, current_user: admin_bot, ip_address: ip_address)

        destroy_service.execute

        event = ::AuditEvents::GroupAuditEvent.last
        expect(event.ip_address).to eq(ip_address)
      end

      context 'with multiple memberships' do
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:project) { create(:project, namespace: group) }

        before do
          subgroup.add_maintainer(member_user)
          project.add_maintainer(member_user)
        end

        it 'records an audit event with the ip address for each membership removal' do
          destroy_service.execute

          group_event_ips = ::AuditEvents::GroupAuditEvent.pluck(:ip_address)
          expect(group_event_ips).to eq([request_ip_address, request_ip_address])
          project_event_ips = ::AuditEvents::ProjectAuditEvent.pluck(:ip_address)
          expect(project_event_ips).to eq([request_ip_address])
        end

        it 'records an audit event with the given ip address when passed a parameter' do
          destroy_service = described_class.new(member, current_user: admin_bot, ip_address: ip_address)

          destroy_service.execute

          group_event_ips = ::AuditEvents::GroupAuditEvent.pluck(:ip_address)
          expect(group_event_ips).to eq([ip_address, ip_address])
          project_event_ips = ::AuditEvents::ProjectAuditEvent.pluck(:ip_address)
          expect(project_event_ips).to eq([ip_address])
        end
      end
    end
  end
end
