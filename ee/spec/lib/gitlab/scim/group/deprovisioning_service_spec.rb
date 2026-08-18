# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Scim::Group::DeprovisioningService, feature_category: :system_access do
  describe '#execute' do
    let_it_be(:admin_bot) { create(:user, :admin_bot) }

    let(:identity) { create(:scim_identity, active: true) }
    let(:group) { identity.group }
    let(:user) { identity.user }

    let(:service) { described_class.new(identity) }

    context 'when user is successfully removed' do
      before do
        create(:group_member, group: group, user: user, access_level: GroupMember::REPORTER)
      end

      context 'when auditing' do
        let(:request_ip_address) { '192.168.188.69' }

        before do
          allow(::Gitlab::RequestContext.instance).to receive(:client_ip).and_return(request_ip_address)
        end

        around do |example|
          RequestStore.begin!
          example.run
          RequestStore.end!
          RequestStore.clear!
        end

        def destroy_audits
          AuditEventReader.where %q("details" LIKE '%:event_name: member_destroyed%')
        end

        context 'without admin_audit_log enabled' do
          before do
            stub_licensed_features(admin_audit_log: false)
          end

          it 'audits the access removal without an IP address', :sidekiq_inline do
            service.execute
            process_scheduled_membership_removals

            event = destroy_audits.last
            expect(destroy_audits.count).to eq(1)
            expect(event.ip_address).to be_nil
            expect(event.details[:reason]).to eq('SCIM')
            expect(event.details[:system_event]).to be true
            expect(event.author_name).to eq('(System)')
          end
        end

        context 'with admin_audit_log enabled' do
          before do
            stub_licensed_features(admin_audit_log: true)
          end

          it "audits the access removal with the request's IP address",
            :sidekiq_inline do
            service.execute
            process_scheduled_membership_removals

            event = destroy_audits.last
            expect(destroy_audits.count).to eq(1)
            expect(event.ip_address).to eq(request_ip_address)
            expect(event.details[:reason]).to eq('SCIM')
            expect(event.details[:system_event]).to be true
            expect(event.author_name).to eq('(System)')
          end
        end
      end

      it 'deactivates scim identity', :sidekiq_inline do
        expect(identity.active).to be true

        service.execute
        process_scheduled_membership_removals

        expect(identity.reload.active).to be false
      end

      it 'schedules group access removal' do
        service.execute

        deletion_schedule = ::Members::DeletionSchedule.where(namespace: group, user: user).first

        expect(deletion_schedule).to be_present
        expect(deletion_schedule.scheduled_by).to eq(admin_bot)
      end

      it 'returns a successful deprovision message' do
        response = service.execute

        expect(response.message).to include("User #{user.name} was removed from #{group.name}.")
      end

      context 'with a SAML identity' do
        let(:saml_provider) { create(:saml_provider, group: group) }

        before do
          create(:group_saml_identity, user: user, saml_provider: saml_provider)
        end

        it 'preserves the saml identity', :sidekiq_inline do
          service.execute
          process_scheduled_membership_removals

          expect(user.reload.identities.count).to eq(1)
        end
      end
    end

    context 'with minimal access role' do
      before do
        stub_licensed_features(minimal_access_role: true)
        create(:group_member, group: group, user: user, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'deactivates scim identity', :sidekiq_inline do
        expect(identity.active).to be true

        service.execute
        process_scheduled_membership_removals

        expect(identity.reload.active).to be false
      end

      it 'schedules group access removal' do
        service.execute

        deletion_schedule = ::Members::DeletionSchedule.where(namespace: group, user: user).first

        expect(deletion_schedule).to be_present
        expect(deletion_schedule.scheduled_by).to eq(admin_bot)
      end

      it 'returns a successful deprovision message' do
        response = service.execute

        expect(response.message).to include("User #{user.name} was removed from #{group.name}.")
      end
    end

    context 'when user is the last owner' do
      before do
        create(:group_member, group: group, user: user, access_level: GroupMember::OWNER)
      end

      it 'does not remove the last owner', :sidekiq_inline do
        service.execute
        process_scheduled_membership_removals

        expect(identity.group.members.pluck(:user_id)).to include(user.id)
      end

      it 'returns the last group owner error' do
        response = service.execute

        expect(response.error?).to be true
        expect(response.errors).to include(
          "Could not remove #{user.name} from #{group.name}. Cannot remove last group owner."
        )
      end
    end

    context 'when user is not a group member' do
      it 'does not change group membership', :sidekiq_inline do
        expect do
          service.execute
          process_scheduled_membership_removals
        end.not_to change { group.members.count }
      end

      it 'deactivates scim identity', :sidekiq_inline do
        expect do
          service.execute
          process_scheduled_membership_removals
        end.to change { identity.active }.from(true).to(false)
      end
    end
  end

  def process_scheduled_membership_removals
    ::Members::SchedulePruneDeletionsWorker.new.perform
  end
end
