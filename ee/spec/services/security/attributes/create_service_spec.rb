# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CreateService, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:category) { create(:security_category, namespace: namespace, editable_state: :editable) }

  let(:params) do
    {
      attributes: [
        {
          name: 'Critical',
          description: 'Critical security level',
          color: '#FF0000'
        },
        {
          name: 'High',
          description: 'High security level',
          color: '#FF8C00'
        }
      ]
    }
  end

  subject(:execute) do
    described_class.new(
      category: category,
      namespace: namespace,
      params: params,
      current_user: user
    ).execute
  end

  before do
    stub_licensed_features(security_attributes: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      it 'returns an error' do
        expect(execute).to be_error
        expect(execute.message).to eq('You are not authorized to perform this action')
      end
    end

    context 'when user has permission' do
      before_all do
        namespace.add_owner(user)
      end

      it 'creates security attributes successfully' do
        expect { execute }.to change { Security::Attribute.count }.by(2)

        expect(execute).to be_success
        expect(execute.payload[:attributes].size).to eq(2)

        attribute1 = execute.payload[:attributes].first
        expect(attribute1.name).to eq('Critical')
        expect(attribute1.description).to eq('Critical security level')
        expect(attribute1.color).to eq(::Gitlab::Color.of('#FF0000'))
        expect(attribute1.editable_state).to eq('editable')
        expect(attribute1.security_category).to eq(category)
        expect(attribute1.namespace).to eq(namespace)
      end

      it 'creates all attributes in a single transaction' do
        expect(category).to receive(:save).once.and_call_original

        expect(execute).to be_success
      end

      it 'creates audit events for each attribute', :request_store do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with({
          author: user,
          scope: namespace,
          target: namespace,
          name: 'security_attribute_created'
        }).and_call_original

        expect(::Gitlab::Audit::EventQueue).to receive(:push).twice.with(
          satisfy { |event| security_attribute_created_event?(event) }
        ).and_call_original

        expect { execute }.to change { AuditEventReader.count }.by(2)

        audit_events = AuditEventReader.last(2)
        audit_events.each do |audit_event|
          expect(audit_event.details).to include(
            event_name: 'security_attribute_created',
            author_name: user.name,
            category_name: category.name
          )
        end

        expect(audit_events.first.details).to include(
          custom_message: 'Created security attribute Critical',
          attribute_name: 'Critical',
          attribute_description: 'Critical security level',
          attribute_color: '#FF0000'
        )

        expect(audit_events.second.details).to include(
          custom_message: 'Created security attribute High',
          attribute_name: 'High',
          attribute_description: 'High security level',
          attribute_color: '#FF8C00'
        )
      end

      context 'when attribute validation fails' do
        let(:params) { { attributes: [{ name: '', description: 'Test description', color: '#FF0000' }] } }

        it 'returns error without creating any attributes' do
          expect { execute }.not_to change { Security::Attribute.count }

          expect(execute).to be_error
          expect(execute.message).to include('Failed to create security attributes')
          expect(execute.message).to include("Name can't be blank")
        end
      end

      context 'when color validation fails' do
        let(:params) do
          {
            attributes: [
              {
                name: 'Test',
                description: 'Test description',
                color: 'invalid-color' # Invalid color format
              }
            ]
          }
        end

        it 'returns error with color validation message' do
          expect(execute).to be_error
          expect(execute.message).to include('Failed to create security attributes')
          expect(execute.message).to include('Color')
        end
      end

      context 'when duplicate name within category' do
        let!(:existing_attribute) do
          create(:security_attribute, security_category: category, name: 'Critical', namespace: namespace)
        end

        it 'returns error for duplicate name' do
          expect(execute).to be_error
          expect(execute.message).to include('Name has already been taken')
        end
      end

      context 'when exceeding attribute limit' do
        let(:limit) { 5 }

        before do
          stub_const("Security::Category::MAX_ATTRIBUTES", limit)
          create_list(:security_attribute, limit - 1, security_category: category, namespace: namespace)
        end

        context 'when at limit' do
          let(:params) do
            {
              attributes: [{ name: "#{limit} Attribute", description: "The best attribute", color: '#000000' }]
            }
          end

          it 'creates attributes' do
            expect { execute }.to change { Security::Attribute.count }.by(1)
            expect(execute).to be_success
          end
        end

        context 'when exceeding limit' do
          let(:params) do
            {
              attributes: [
                { name: 'Extra Attribute', description: 'Should not be allowed', color: '#123456' },
                { name: 'Another One', description: 'Also too much', color: '#654321' }
              ]
            }
          end

          it 'returns error' do
            expect { execute }.not_to change { Security::Attribute.count }
            expect(execute).to be_error
            expect(execute.message).to include("cannot have more than #{limit} attributes per category")
          end
        end
      end

      context 'when description is missing' do
        let(:params) { { attributes: [{ name: 'Test', description: nil, color: '#FF0000' }] } }

        it 'returns validation error' do
          expect(execute).to be_error
          expect(execute.message).to include("Description can't be blank")
        end
      end

      context 'when category is not editable' do
        before do
          category.update!(editable_state: :locked)
        end

        it 'returns non-editable error' do
          expect(execute).to be_error
          expect(execute.message).to eq("You can not edit this category's attributes.")
        end
      end

      context 'when category save fails' do
        before do
          # Mock the category to fail validation but allow other methods
          allow(category).to receive_messages(valid?: true, save: false)
          allow(category.errors).to receive(:full_messages).and_return(['Category validation failed'])
        end

        it 'returns error with category errors' do
          expect(execute).to be_error
          expect(execute.message).to include('Failed to create security attributes')
          expect(execute.message).to include('Category validation failed')
        end
      end

      context 'when no attributes are provided' do
        let(:params) { { attributes: [] } }

        it 'succeeds with empty attributes' do
          expect(execute).to be_success
          expect(execute.payload[:attributes]).to be_empty
        end

        it 'does not create audit events when no attributes' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)
          expect(execute).to be_success
        end
      end
    end
  end

  def security_attribute_created_event?(event)
    event.is_a?(AuditEvent) && event.details[:event_name] == 'security_attribute_created'
  end
end
