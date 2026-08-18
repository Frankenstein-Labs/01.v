# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::Abuse::NamespaceBans::CreateService, feature_category: :insider_threat do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }

  let(:service) { described_class.new(current_user: current_user, user: user, namespace: namespace) }

  describe '#execute' do
    subject(:response) { service.execute }

    context 'when passing a root namespace' do
      it { is_expected.to be_success }

      context 'with audit events' do
        context 'when licensed' do
          before do
            stub_licensed_features(admin_audit_log: true, audit_events: true, extended_audit_events: true)
          end

          context 'when current_user is nil' do
            let_it_be(:current_user) { nil }

            it 'creates an audit event with (System) as the author', :aggregate_failures do
              expect { response }.to change { AuditEventReader.count }.by(1)

              expect(AuditEventReader.last).to have_attributes(
                author: Gitlab::Audit::UnauthenticatedAuthor,
                entity_type: 'Group',
                entity_id: namespace.id,
                target_details: user.username,
                details: include(
                  author_name: "(System)",
                  event_name: 'namespace_ban_created',
                  custom_message: 'Banned user'
                )
              )
            end
          end

          it 'creates an audit event', :aggregate_failures do
            expect { response }.to change { AuditEventReader.count }.by(1)

            expect(AuditEventReader.last).to have_attributes(
              author: current_user,
              entity_type: 'Group',
              entity_id: namespace.id,
              target_details: user.username,
              details: include(
                event_name: 'namespace_ban_created',
                custom_message: 'Banned user'
              )
            )
          end
        end

        context 'when not licensed' do
          before do
            stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
          end

          it 'does not create an audit event' do
            expect { response }.not_to change { AuditEventReader.count }
          end
        end
      end
    end

    context 'when passing a nested namespace' do
      let(:namespace) { build(:group, :nested) }

      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to eq('Namespace must be a root namespace')
      end
    end

    context 'when passing an already banned user' do
      before do
        service.execute
      end

      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to eq('User already banned from namespace')
      end
    end
  end
end
