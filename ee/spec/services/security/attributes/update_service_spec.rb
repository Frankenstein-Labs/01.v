# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::UpdateService, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be(:category) { create(:security_category, namespace: namespace) }
  let_it_be_with_reload(:attribute) do
    create(:security_attribute,
      security_category: category,
      namespace: namespace,
      name: 'Original Name',
      description: 'Original Description',
      color: '#FF0000',
      editable_state: :editable
    )
  end

  let(:params) do
    {
      name: 'Updated Name',
      description: 'Updated Description',
      color: '#00FF00'
    }
  end

  subject(:execute) { described_class.new(attribute: attribute, params: params, current_user: user).execute }

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      it 'returns an error' do
        result = execute

        expect(result).to be_error
        expect(result.message).to eq('You are not authorized to perform this action')
      end
    end

    context 'when user has permission' do
      before_all do
        namespace.add_owner(user)
      end

      it 'updates the attribute successfully' do
        expect(execute).to be_success

        attribute.reload
        expect(attribute.name).to eq('Updated Name')
        expect(attribute.description).to eq('Updated Description')
        expect(attribute.color).to eq(::Gitlab::Color.of('#00FF00'))
      end

      it 'creates an audit event' do
        expect { execute }.to change { AuditEventReader.count }.by(1)

        audit_event = AuditEventReader.last
        expect(audit_event.details).to include(
          event_name: 'security_attribute_updated',
          author_name: user.name,
          custom_message: "Updated security attribute Updated Name",
          attribute_name: 'Updated Name',
          attribute_description: 'Updated Description',
          attribute_color: '#00FF00',
          category_name: category.name,
          previous_values: {
            name: 'Original Name',
            description: 'Original Description',
            color: '#FF0000'
          }
        )
      end

      context 'when attribute is not editable' do
        let(:attribute) do
          create(:security_attribute, security_category: category, namespace: namespace, editable_state: :locked)
        end

        it 'returns error without updating' do
          expect(execute).to be_error
          expect(execute.message).to eq('Cannot update non editable attribute')
          expect(attribute.name).not_to eq('Updated Name')
        end
      end

      context 'when validation fails' do
        context 'with empty name' do
          let(:params) { { name: '' } }

          it 'returns validation error' do
            expect(execute).to be_error
            expect(execute.message).to include('Failed to update security attribute')
            expect(execute.message).to include("Name can't be blank")
          end
        end

        context 'with invalid color' do
          let(:params) { { color: 'not-a-color' } }

          it 'returns validation error' do
            expect(execute).to be_error
            expect(execute.message).to include('Failed to update security attribute')
            expect(execute.message).to include('Color')
          end
        end

        context 'with description too long' do
          let(:params) { { description: 'a' * 256 } }

          it 'returns length validation error' do
            expect(execute).to be_error
            expect(execute.message).to include('Failed to update security attribute')
            expect(execute.message).to include('Description is too long')
          end
        end
      end

      context 'when no params provided' do
        let(:params) { {} }

        it 'succeeds without changing anything' do
          expect(execute).to be_success

          attribute.reload
          expect(attribute.name).to eq('Original Name')
          expect(attribute.description).to eq('Original Description')
          expect(attribute.color).to eq(::Gitlab::Color.of('#FF0000'))
        end
      end
    end
  end
end
