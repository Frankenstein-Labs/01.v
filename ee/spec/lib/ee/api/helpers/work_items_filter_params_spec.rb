# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::WorkItemsFilterParams, feature_category: :portfolio_management do
  let_it_be(:namespace) { create(:group) }

  subject(:transform) { described_class.new(params, resource_parent: namespace).transform }

  describe '#transform' do
    context 'with status filter' do
      context 'when status is absent' do
        let(:params) { { state: 'opened' } }

        it 'does not add a status key' do
          expect(transform).not_to have_key(:status)
        end
      end

      context 'when status[:name] is provided' do
        let(:params) { { status: { name: 'In progress' } } }

        it 'passes the name through without modification' do
          expect(transform[:status]).to eq({ name: 'In progress' })
        end
      end

      context 'when status[:id] is provided' do
        context 'when resource_parent is nil' do
          subject(:transform) { described_class.new(params, resource_parent: nil).transform }

          let(:params) { { status: { id: 1 } } }

          it 'does not set id and does not raise' do
            expect(transform[:status]).not_to have_key(:id)
          end
        end

        context 'when the namespace has custom statuses' do
          let_it_be(:custom_status) { create(:work_item_custom_status, namespace: namespace) }

          context 'when the custom status exists' do
            let(:params) { { status: { id: custom_status.id } } }

            it 'resolves the ID to the Custom::Status object' do
              expect(transform[:status][:id]).to eq(custom_status)
            end
          end

          context 'when the custom status does not exist' do
            let(:params) { { status: { id: non_existing_record_id } } }

            it 'sets id to nil' do
              expect(transform[:status][:id]).to be_nil
            end
          end
        end

        context 'when the namespace has no custom statuses' do
          let(:system_status) { ::WorkItems::Statuses::SystemDefined::Status.find_by(id: 1) }

          context 'when the system-defined status exists' do
            let(:params) { { status: { id: 1 } } }

            it 'resolves the ID to the SystemDefined::Status object' do
              expect(transform[:status][:id]).to eq(system_status)
            end
          end

          context 'when the system-defined status does not exist' do
            let(:params) { { status: { id: non_existing_record_id } } }

            it 'sets id to nil' do
              expect(transform[:status][:id]).to be_nil
            end
          end
        end
      end
    end
  end
end
