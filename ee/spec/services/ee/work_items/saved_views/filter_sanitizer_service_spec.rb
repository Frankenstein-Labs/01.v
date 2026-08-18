# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::SavedViews::FilterSanitizerService, feature_category: :planning_views do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:namespace) { group }
  let(:filter_data) { {} }

  subject(:service) do
    described_class.new(filter_data: filter_data, namespace: namespace, current_user: current_user)
  end

  describe '#execute' do
    subject(:result) { service.execute }

    describe 'iteration validation' do
      let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

      context 'with valid iteration ID' do
        let(:filter_data) { { iteration_id: [iteration.id] } }

        it 'converts ID to string' do
          expect(result.payload[:filters][:iteration_id]).to eq([iteration.id.to_s])
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with deleted iteration' do
        let(:filter_data) { { iteration_id: [non_existing_record_id] } }

        it 'returns warning for missing iteration' do
          expect(result.payload[:filters][:iteration_id]).to be_nil
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :iteration_id, message: '1 iteration(s) not found' }
          )
        end
      end

      context 'with mixed valid and deleted iterations' do
        let(:filter_data) { { iteration_id: [iteration.id, non_existing_record_id] } }

        it 'returns found IDs and warning for missing' do
          expect(result.payload[:filters][:iteration_id]).to eq([iteration.id.to_s])
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :iteration_id, message: '1 iteration(s) not found' }
          )
        end
      end

      context 'with negated iteration' do
        let(:filter_data) { { not: { iteration_id: [iteration.id] } } }

        it 'converts negated ID to string' do
          expect(result.payload[:filters][:not][:iteration_id]).to eq([iteration.id.to_s])
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with negated deleted iteration' do
        let(:filter_data) { { not: { iteration_id: [non_existing_record_id] } } }

        it 'returns warning for missing negated iteration' do
          expect(result.payload[:filters][:not][:iteration_id]).to be_nil
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :not_iteration_id, message: '1 iteration(s) not found' }
          )
        end
      end
    end

    describe 'iteration cadence validation' do
      let_it_be(:cadence) { create(:iterations_cadence, group: group) }

      context 'with valid iteration cadence IDs' do
        let(:filter_data) { { iteration_cadence_ids: [cadence.id] } }

        it 'converts IDs to global IDs' do
          expect(result.payload[:filters][:iteration_cadence_id]).to eq([cadence.to_gid.to_s])
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with deleted iteration cadence' do
        let(:filter_data) { { iteration_cadence_ids: [non_existing_record_id] } }

        it 'returns warning for missing cadence' do
          expect(result.payload[:filters][:iteration_cadence_id]).to be_nil
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :iteration_cadence_id, message: '1 iteration cadence(s) not found' }
          )
        end
      end

      context 'with mixed valid and deleted cadences' do
        let(:filter_data) { { iteration_cadence_ids: [cadence.id, non_existing_record_id] } }

        it 'returns found IDs and warning for missing' do
          expect(result.payload[:filters][:iteration_cadence_id]).to eq([cadence.to_gid.to_s])
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :iteration_cadence_id, message: '1 iteration cadence(s) not found' }
          )
        end
      end
    end

    describe 'status validation' do
      let_it_be(:status) { create(:work_item_custom_status, namespace: group, name: 'In Progress') }
      let_it_be(:group_without_custom_statuses) { create(:group) }

      context 'with legacy saved view (no custom key)' do
        let(:filter_data) { { status: { id: status.id, input_format: :name } } }

        it 'falls back to Finder and converts status ID to name hash' do
          expect(result.payload[:filters][:status]).to eq({ name: status.name })
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with match: stored custom: true and namespace has custom statuses' do
        let(:filter_data) { { status: { id: status.id, input_format: :name, custom: true } } }

        it 'resolves to the custom status name', :aggregate_failures do
          expect(result.payload[:filters][:status]).to eq({ name: status.name })
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with match: stored custom: false and namespace has no custom statuses' do
        let(:namespace) { group_without_custom_statuses }
        let(:system_defined_status) { WorkItems::Statuses::SystemDefined::Status.find_by_name('Done') }
        let(:filter_data) { { status: { id: system_defined_status.id, input_format: :name, custom: false } } }

        it 'resolves to the system-defined status name', :aggregate_failures do
          expect(result.payload[:filters][:status]).to eq({ name: 'Done' })
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with upgrade: stored custom: false, namespace now has custom statuses' do
        let(:system_defined_status) { WorkItems::Statuses::SystemDefined::Status.find_by_name('Done') }
        let(:filter_data) { { status: { id: system_defined_status.id, input_format: :name, custom: false } } }

        context 'when a converted custom status exists for the system-defined ID' do
          let(:converted_status) do
            create(:work_item_custom_status, :done, namespace: group,
              converted_from_system_defined_status_identifier: system_defined_status.id)
          end

          before do
            converted_status
          end

          it 'maps to the converted custom status name', :aggregate_failures do
            expect(result.payload[:filters][:status]).to eq({ name: converted_status.name })
            expect(result.payload[:warnings]).to be_empty
          end
        end

        context 'when no converted custom status exists' do
          it 'strips the filter and adds a warning', :aggregate_failures do
            expect(result.payload[:filters][:status]).to be_nil
            expect(result.payload[:warnings]).to contain_exactly(
              {
                field: :status,
                message: 'Status filter removed: the status no longer exists after enabling custom statuses'
              }
            )
          end
        end
      end

      context 'with downgrade: stored custom: true, namespace now uses system-defined statuses' do
        let(:namespace) { group_without_custom_statuses }
        let(:filter_data) { { status: { id: non_existing_record_id, input_format: :name, custom: true } } }

        it 'strips the filter and adds a warning', :aggregate_failures do
          expect(result.payload[:filters][:status]).to be_nil
          expect(result.payload[:warnings]).to contain_exactly(
            {
              field: :status,
              message: 'Status filter removed: the status no longer exists after disabling custom statuses'
            }
          )
        end
      end

      context 'with deleted status (legacy, no custom key)' do
        let(:filter_data) { { status: { id: non_existing_record_id, input_format: :name } } }

        it 'returns warning for missing status' do
          expect(result.payload[:filters][:status]).to be_nil
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :status, message: 'Status not found' }
          )
        end
      end

      context 'when status is not a hash' do
        let(:filter_data) { { status: 'invalid' } }

        it 'does not process status filter' do
          expect(result.payload[:filters][:status]).to be_nil
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'when status hash has no id' do
        let(:filter_data) { { status: { name: 'Some Status' } } }

        it 'does not process status filter' do
          expect(result.payload[:filters][:status]).to be_nil
          expect(result.payload[:warnings]).to be_empty
        end
      end
    end

    describe 'custom field validation' do
      let_it_be(:custom_field) do
        create(:custom_field, namespace: group)
      end

      let_it_be(:option1) { create(:custom_field_select_option, custom_field: custom_field) }
      let_it_be(:option2) { create(:custom_field_select_option, custom_field: custom_field) }

      context 'with valid custom field and options' do
        let(:filter_data) do
          {
            custom_field: [
              { custom_field_id: custom_field.id.to_s, selected_option_ids: [option1.id.to_s, option2.id.to_s] }
            ]
          }
        end

        it 'converts IDs to global IDs' do
          expect(result.payload[:filters][:custom_field]).to contain_exactly(
            {
              custom_field_id: custom_field.to_gid.to_s,
              selected_option_ids: [option1.to_gid.to_s, option2.to_gid.to_s]
            }
          )
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with deleted custom field option' do
        let(:filter_data) do
          {
            custom_field: [
              { custom_field_id: custom_field.id.to_s,
                selected_option_ids: [option1.id.to_s, non_existing_record_id.to_s] }
            ]
          }
        end

        it 'returns found options as GIDs and warning for missing' do
          expect(result.payload[:filters][:custom_field]).to contain_exactly(
            {
              custom_field_id: custom_field.to_gid.to_s,
              selected_option_ids: [option1.to_gid.to_s]
            }
          )
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :custom_field, message: "1 option(s) not found for custom field #{custom_field.id}" }
          )
        end
      end

      context 'with deleted custom field' do
        let(:filter_data) do
          {
            custom_field: [
              { custom_field_id: non_existing_record_id.to_s, selected_option_ids: ['1'] }
            ]
          }
        end

        it 'returns warning for missing custom field' do
          expect(result.payload[:filters][:custom_field]).to be_empty
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :custom_field, message: "Custom field #{non_existing_record_id} not found" }
          )
        end
      end

      context 'with negated custom field' do
        let(:filter_data) do
          {
            not: {
              custom_field: [
                { custom_field_id: custom_field.id.to_s, selected_option_ids: [option1.id.to_s] }
              ]
            }
          }
        end

        it 'converts negated IDs to global IDs' do
          expect(result.payload[:filters][:not][:custom_field]).to contain_exactly(
            {
              custom_field_id: custom_field.to_gid.to_s,
              selected_option_ids: [option1.to_gid.to_s]
            }
          )
          expect(result.payload[:warnings]).to be_empty
        end
      end

      context 'with negated deleted custom field' do
        let(:filter_data) do
          {
            not: {
              custom_field: [
                { custom_field_id: non_existing_record_id.to_s, selected_option_ids: ['1'] }
              ]
            }
          }
        end

        it 'returns warning for missing negated custom field' do
          expect(result.payload[:filters][:not][:custom_field]).to be_empty
          expect(result.payload[:warnings]).to contain_exactly(
            { field: :not_custom_field, message: "Custom field #{non_existing_record_id} not found" }
          )
        end
      end

      context 'with OR custom field' do
        let(:filter_data) do
          {
            or: {
              custom_field: [
                { custom_field_id: custom_field.id.to_s, selected_option_ids: [option1.id.to_s, option2.id.to_s] }
              ]
            }
          }
        end

        it 'converts OR IDs to global IDs' do
          expect(result.payload[:filters][:or][:custom_field]).to contain_exactly(
            {
              custom_field_id: custom_field.to_gid.to_s,
              selected_option_ids: [option1.to_gid.to_s, option2.to_gid.to_s]
            }
          )
          expect(result.payload[:warnings]).to be_empty
        end
      end
    end

    describe 'error handling' do
      context 'when an ArgumentError is raised during validation' do
        let(:filter_data) { { iteration_id: [1] } }

        before do
          allow(service).to receive(:validate_iteration).and_raise(ArgumentError, 'Invalid filter format')
        end

        it 'returns an error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to eq('Invalid filter format')
        end
      end
    end

    describe 'combined EE and CE filters' do
      let_it_be(:assignee) { create(:user) }
      let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }
      let_it_be(:cadence) { create(:iterations_cadence, group: group) }

      let(:filter_data) do
        {
          state: 'opened',
          assignee_ids: [assignee.id],
          iteration_id: [iteration.id, non_existing_record_id],
          iteration_cadence_ids: [cadence.id]
        }
      end

      it 'processes all filters and collects warnings' do
        expect(result.payload[:filters]).to include(
          state: 'opened',
          assignee_usernames: [assignee.username],
          iteration_id: [iteration.id.to_s],
          iteration_cadence_id: [cadence.to_gid.to_s]
        )
        expect(result.payload[:warnings]).to contain_exactly(
          { field: :iteration_id, message: '1 iteration(s) not found' }
        )
      end
    end
  end
end
