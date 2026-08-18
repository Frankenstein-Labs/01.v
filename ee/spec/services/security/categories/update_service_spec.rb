# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Categories::UpdateService, feature_category: :security_asset_inventories do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }
  let_it_be_with_reload(:category) do
    create(:security_category,
      namespace: namespace,
      name: 'original name',
      description: 'original description',
      editable_state: :editable,
      multiple_selection: false
    )
  end

  let(:params) do
    {
      name: 'updated name',
      description: 'updated description'
    }
  end

  subject(:execute) { described_class.new(category: category, params: params, current_user: current_user).execute }

  before do
    stub_licensed_features(security_attributes: true)
  end

  context 'when user does not have permission' do
    let(:current_user) { create(:user) }

    it 'does not update the security category' do
      expect { execute }.not_to change { category.reload.name }
    end

    it 'responds with an error message' do
      expect(execute.message).to eq('You are not authorized to perform this action')
    end

    it 'responds with an error service response' do
      expect(execute.success?).to be false
    end
  end

  context 'when using invalid parameters' do
    context 'when name is blank' do
      before do
        params[:name] = ''
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(response.success?).to be_falsey
        expect(response.message).to include "Failed to update security category"
      end

      it 'does not update the category' do
        expect { execute }.not_to change { category.reload.name }
      end
    end

    context 'when name is too long' do
      before do
        params[:name] = 'a' * 256
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(response.success?).to be false
        expect(response.message).to include "is too long (maximum is 255 characters)"
      end
    end

    context 'when description is too long' do
      before do
        params[:description] = 'a' * 256
      end

      let(:response) { execute }

      it 'responds with an error service response' do
        expect(response.success?).to be false
        expect(response.message).to include "is too long (maximum is 255 characters)"
      end
    end
  end

  context 'when updating with valid parameters' do
    context 'when params are empty' do
      let(:params) { {} }

      it 'does not change any attributes and returns false' do
        original_category = category

        result = execute

        expect(category.reload.attributes).to eq(original_category.attributes)
        expect(result.success?).to be false
      end
    end

    it 'updates the security category' do
      result = execute
      category.reload

      expect(result.success?).to be true
      expect(category.name).to eq(params[:name])
      expect(category.description).to eq(params[:description])
    end

    it 'responds with a successful service response' do
      expect(execute.success?).to be true
    end

    it 'returns the updated category in payload' do
      result = execute
      expect(result.payload[:category]).to eq(category)
    end

    it 'creates an audit event' do
      expect { execute }.to change { AuditEventReader.count }.by(1)

      audit_event = AuditEventReader.last

      expect(audit_event.details).to include(
        event_name: 'security_category_updated',
        author_name: current_user.name,
        custom_message: "Updated security category #{params[:name]}",
        category_name: params[:name],
        updated_fields: %i[name description],
        name: params[:name],
        description: params[:description]
      )
    end
  end

  context 'when updating only specific fields' do
    context 'when updating only name' do
      let(:params) { { name: 'only name updated' } }

      it 'updates only the name field' do
        execute
        category.reload

        expect(category.name).to eq('only name updated')
        expect(category.description).to eq('original description')
        expect(category.editable_state).to eq('editable')
      end
    end

    context 'when updating only description' do
      let(:params) { { description: 'only description updated' } }

      it 'updates only the description field' do
        execute
        category.reload

        expect(category.name).to eq('original name')
        expect(category.description).to eq('only description updated')
        expect(category.editable_state).to eq('editable')
      end
    end
  end

  context 'when name conflicts with existing category in same namespace' do
    let!(:existing_category) { create(:security_category, namespace: namespace, name: 'existing name') }

    before do
      params[:name] = 'existing name'
    end

    it 'responds with an error service response' do
      response = execute
      expect(response.success?).to be false
      expect(response.payload.messages[:name]).to include "has already been taken"
    end

    it 'does not update the category' do
      expect { execute }.not_to change { category.reload.name }
    end
  end

  context 'when name conflicts with existing category in different namespace' do
    let(:other_namespace) { create(:group) }
    let!(:existing_category) { create(:security_category, namespace: other_namespace, name: 'existing name') }

    before do
      params[:name] = 'existing name'
    end

    it 'successfully updates the category' do
      result = execute
      expect(result.success?).to be true
      expect(category.reload.name).to eq('existing name')
    end
  end

  context 'when trying to update namespace' do
    let(:other_namespace) { create(:group) }
    let(:params) { { namespace: other_namespace } }

    it 'does not update the namespace' do
      execute
      expect(category.reload.namespace).to eq(namespace)
    end

    it 'ignores the namespace parameter' do
      result = execute
      expect(result.success?).to be false
    end
  end
end
