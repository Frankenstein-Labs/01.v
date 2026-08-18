# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::DestroyService, feature_category: :security_asset_inventories do
  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:namespace, freeze: false) { create(:group) }
  let_it_be_with_reload(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let_it_be(:editable_attribute, freeze: false) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :editable,
      name: 'Editable Attribute')
  end

  let_it_be(:locked_attribute, freeze: false) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      editable_state: :locked,
      name: 'Locked Attribute')
  end

  let(:attribute) { editable_attribute }

  subject(:execute) do
    described_class.new(
      attribute: attribute,
      current_user: user
    ).execute
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      it 'returns an unauthorized error' do
        expect { execute }.not_to change { Security::Attribute.count }

        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to perform this action')
      end
    end

    context 'when user has permission' do
      before_all do
        namespace.add_owner(user)
      end

      context 'when attribute is editable' do
        it 'soft deletes the attribute successfully and returns its global ID' do
          expected_gid = attribute.to_global_id.to_s

          expect { execute }
            .to not_change { Security::Attribute.unscoped.count }
            .and change { Security::Attribute.not_deleted.count }.by(-1)

          expect(execute).to be_success
          expect(execute.payload[:deleted_attribute_gid].to_s).to eq(expected_gid)

          attribute.reload
          expect(attribute.deleted_at).to be_present
          expect(attribute.deleted?).to be true
        end

        it 'enqueues the project associations cleanup worker' do
          expect(Security::Attributes::CleanupProjectToSecurityAttributeWorker)
            .to receive(:perform_async).with(attribute.id)

          execute
        end

        it 'creates an audit event' do
          expect { execute }.to change { AuditEventReader.count }.by(1)

          audit_event = AuditEventReader.last
          expect(audit_event.details).to include(
            event_name: 'security_attribute_deleted',
            author_name: user.name,
            custom_message: "Deleted security attribute #{attribute.name}",
            attribute_name: attribute.name,
            attribute_description: attribute.description,
            category_name: category.name
          )
        end

        it 'does not create an audit event when deletion fails' do
          allow(attribute).to receive(:destroy).and_return(false)
          expect { execute }.not_to change { AuditEventReader.count }
        end

        it 'does not enqueue worker when deletion fails' do
          allow(attribute).to receive(:destroy).and_return(false)

          expect(Security::Attributes::CleanupProjectToSecurityAttributeWorker)
            .not_to receive(:perform_async)

          execute
        end
      end

      context 'when attribute is locked' do
        let(:attribute) { locked_attribute }

        it 'returns an error and does not delete the attribute' do
          expect { execute }.not_to change { Security::Attribute.count }

          expect(execute).to be_error
          expect(execute.message).to eq('Cannot delete non-editable attribute')

          expect(Security::Attribute.exists?(locked_attribute.id)).to be_truthy
        end
      end

      context 'when deletion fails due to database error' do
        before do
          allow(attribute).to receive(:destroy).and_raise(
            ActiveRecord::RecordNotDestroyed.new('Database constraint violation')
          )
        end

        it 'returns an error with the failure message' do
          expect { execute }.not_to change { Security::Attribute.count }

          expect(execute).to be_error
          expect(execute.message).to eq('Failed to delete attributes: Database constraint violation')
        end
      end
    end
  end
end
