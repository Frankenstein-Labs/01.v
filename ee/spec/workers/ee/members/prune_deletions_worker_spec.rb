# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::PruneDeletionsWorker, :saas, feature_category: :seat_cost_management do
  let(:worker) { described_class.new }

  describe '#perform_work' do
    subject(:perform_work) { worker.perform_work }

    context 'with Members::DeletionSchedule records' do
      let_it_be(:group) { create(:group) }
      let_it_be(:owner) { create(:user) }
      let_it_be(:user) { create(:user) }
      let_it_be_with_reload(:schedule) do
        create(:members_deletion_schedules, user: user, namespace: group, scheduled_by: owner)
      end

      before_all do
        group.add_owner(owner)
        group.add_developer(user)
      end

      it_behaves_like 'an idempotent worker' do
        context 'with a saml identity' do
          before do
            saml_provider = create(:saml_provider, group: group)
            create(:group_saml_identity, user: user, saml_provider: saml_provider)
          end

          it 'preserves the saml identity' do
            expect { perform_work }.not_to change { user.reload.identities.count }
          end
        end

        describe 'ip address in audit events' do
          before do
            stub_licensed_features(admin_audit_log: true)
          end

          context 'with an ip address and multiple memberships to remove' do
            let(:request_ip_address) { '44.55.66.77' }

            before do
              subgroup = create(:group, parent: group)
              project = create(:project, group: subgroup)

              subgroup.add_maintainer(user)
              project.add_owner(user)

              schedule.update!(ip_address: request_ip_address)
            end

            it 'records the ip_address with each audit event' do
              perform_work

              expect(::AuditEvents::GroupAuditEvent.pluck(:ip_address)).to eq([request_ip_address, request_ip_address])
              expect(::AuditEvents::ProjectAuditEvent.pluck(:ip_address)).to eq([request_ip_address])
            end
          end

          context 'without an ip_address' do
            it 'creates an event with a nil ip address' do
              perform_work

              event = ::AuditEvents::GroupAuditEvent.first
              expect(event.ip_address).to be_nil
            end
          end
        end
      end
    end
  end
end
