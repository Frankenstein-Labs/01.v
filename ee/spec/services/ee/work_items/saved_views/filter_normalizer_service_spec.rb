# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::SavedViews::FilterNormalizerService, feature_category: :planning_views do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:custom_field) do
    create(:custom_field, namespace: group, name: 'Priority')
  end

  let_it_be(:custom_field_option1) do
    create(:custom_field_select_option, custom_field: custom_field, value: 'High')
  end

  let_it_be(:custom_field_option2) do
    create(:custom_field_select_option, custom_field: custom_field, value: 'Low')
  end

  let_it_be(:iteration_cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: iteration_cadence, group: group) }

  let_it_be(:status) { create(:work_item_custom_status, namespace: group, name: 'In Progress') }

  let(:container) { project }
  let(:filter_data) { {} }

  subject(:service) { described_class.new(filter_data: filter_data, container: container, current_user: current_user) }

  before_all do
    group.add_developer(current_user)
    project.add_developer(current_user)
  end

  describe '#execute' do
    context 'with static filters' do
      let(:filter_data) do
        { health_status_filter: 'on_track', iteration_wildcard_id: 'CURRENT', weight: 5 }
      end

      it 'preserves static filters unchanged' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to include(
          health_status_filter: 'on_track',
          iteration_wildcard_id: 'CURRENT',
          weight: 5
        )
      end
    end

    context 'with negated static filters' do
      let(:filter_data) do
        {
          not: {
            health_status_filter: 'at_risk',
            iteration_wildcard_id: 'NONE',
            weight: 3
          }
        }
      end

      it 'normalizes negated static filters' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:not]).to include(
          health_status_filter: 'at_risk',
          iteration_wildcard_id: 'NONE',
          weight: 3
        )
      end
    end

    context 'with combined FOSS and EE static filters' do
      let(:filter_data) do
        {
          issue_types: ['ISSUE'],
          state: 'opened',
          health_status_filter: 'needs_attention',
          weight: 2,
          not: {
            issue_types: ['EPIC'],
            health_status_filter: 'on_track',
            weight: 1
          }
        }
      end

      it 'normalizes all static filters correctly' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to include(
          issue_types: ['ISSUE'],
          state: 'opened',
          health_status_filter: 'needs_attention',
          weight: 2
        )
        expect(result.payload[:not]).to include(
          issue_types: ['EPIC'],
          health_status_filter: 'on_track',
          weight: 1
        )
      end
    end

    context 'with all health_status_filter values' do
      let(:filter_data) { { health_status_filter: health_status } }

      where(:health_status) do
        %w[on_track needs_attention at_risk]
      end

      with_them do
        it 'preserves the health_status_filter value' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:health_status_filter]).to eq(health_status)
        end
      end
    end

    context 'with all iteration_wildcard_id values' do
      let(:filter_data) { { iteration_wildcard_id: wildcard } }

      where(:wildcard) do
        %w[NONE ANY CURRENT]
      end

      with_them do
        it 'preserves the iteration_wildcard_id value' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:iteration_wildcard_id]).to eq(wildcard)
        end
      end
    end

    context 'with weight filter' do
      let(:filter_data) { { weight: weight_value } }

      where(:weight_value) do
        [0, 1, 5, 10, 100]
      end

      with_them do
        it 'preserves the weight value' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:weight]).to eq(weight_value)
        end
      end
    end

    context 'with custom field filters' do
      context 'when custom_field_id is provided' do
        let(:filter_data) do
          {
            custom_field: [
              {
                custom_field_id: custom_field.id,
                selected_option_ids: [custom_field_option1.id, custom_field_option2.id]
              }
            ]
          }
        end

        it 'normalizes custom field filters with IDs as strings' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:custom_field]).to eq([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s, custom_field_option2.id.to_s]
            }
          ])
        end
      end

      context 'when custom_field_name is provided' do
        let(:filter_data) do
          {
            custom_field: [
              {
                custom_field_name: 'Priority',
                selected_option_ids: [custom_field_option1.id]
              }
            ]
          }
        end

        it 'finds custom field by name and normalizes' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:custom_field]).to eq([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s]
            }
          ])
        end

        context 'when custom field name does not exist' do
          let(:filter_data) do
            {
              custom_field: [
                {
                  custom_field_name: 'NonExistent',
                  selected_option_ids: [custom_field_option1.id]
                }
              ]
            }
          end

          it 'filters out the invalid custom field' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:custom_field]).to eq([])
          end
        end
      end

      context 'when selected_option_values are provided' do
        let(:filter_data) do
          {
            custom_field: [
              {
                custom_field_id: custom_field.id,
                selected_option_values: %w[High Low]
              }
            ]
          }
        end

        it 'converts option values to option IDs' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:custom_field].first[:custom_field_id]).to eq(custom_field.id.to_s)
          expect(result.payload[:custom_field].first[:selected_option_ids]).to match_array(
            [custom_field_option1.id.to_s, custom_field_option2.id.to_s]
          )
        end

        context 'when option values do not exist' do
          let(:filter_data) do
            {
              custom_field: [
                {
                  custom_field_id: custom_field.id,
                  selected_option_values: ['NonExistent']
                }
              ]
            }
          end

          it 'filters out the custom field with no valid options' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:custom_field]).to eq([])
          end
        end
      end

      context 'when both custom_field_name and selected_option_values are provided' do
        let(:filter_data) do
          {
            custom_field: [
              {
                custom_field_name: 'Priority',
                selected_option_values: ['High']
              }
            ]
          }
        end

        it 'normalizes both field name and option values' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:custom_field]).to eq([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s]
            }
          ])
        end
      end

      context 'when multiple custom fields are provided' do
        let_it_be(:custom_field2) { create(:custom_field, namespace: group, name: 'Severity') }

        let_it_be(:custom_field2_option) do
          create(:custom_field_select_option, custom_field: custom_field2, value: 'Critical')
        end

        let(:filter_data) do
          {
            custom_field: [
              {
                custom_field_id: custom_field.id,
                selected_option_ids: [custom_field_option1.id]
              },
              {
                custom_field_name: 'Severity',
                selected_option_values: ['Critical']
              }
            ]
          }
        end

        it 'normalizes all custom fields' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:custom_field]).to match_array([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s]
            },
            {
              custom_field_id: custom_field2.id.to_s,
              selected_option_ids: [custom_field2_option.id.to_s]
            }
          ])
        end

        context 'when custom field has neither ID nor name' do
          let(:filter_data) do
            { custom_field: [{ selected_option_ids: [custom_field_option1.id] }] }
          end

          it 'filters out the invalid custom field' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:custom_field]).to eq([])
          end
        end

        context 'when custom field has neither selected_option_ids or selected_option_values' do
          let(:filter_data) { { custom_field: [{ custom_field_id: custom_field.id }] } }

          it 'filters out the custom field with no options' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:custom_field]).to eq([])
          end
        end

        context 'when selected options are empty after normalization' do
          let(:filter_data) do
            { custom_field: [{ custom_field_id: custom_field.id, selected_option_values: [] }] }
          end

          it 'filters out the custom field with no options' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:custom_field]).to eq([])
          end
        end
      end

      context 'with negated custom fields' do
        let(:filter_data) do
          {
            not: {
              custom_field: [
                {
                  custom_field_id: custom_field.id,
                  selected_option_ids: [custom_field_option1.id]
                }
              ]
            }
          }
        end

        it 'normalizes negated custom field filters' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload.dig(:not, :custom_field)).to eq([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s]
            }
          ])
        end
      end

      context 'with OR custom fields' do
        let(:filter_data) do
          {
            or: {
              custom_field: [
                {
                  custom_field_id: custom_field.id,
                  selected_option_ids: [custom_field_option1.id]
                }
              ]
            }
          }
        end

        it 'normalizes OR custom field filters' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload.dig(:or, :custom_field)).to eq([
            {
              custom_field_id: custom_field.id.to_s,
              selected_option_ids: [custom_field_option1.id.to_s]
            }
          ])
        end
      end
    end

    context 'with iteration_id filter' do
      let(:filter_data) { { iteration_id: iteration.id } }

      it 'preserves iteration_id as-is' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:iteration_id]).to eq(iteration.id)
      end

      context 'with negated iteration_id' do
        let(:filter_data) do
          {
            not: {
              iteration_id: iteration.id
            }
          }
        end

        it 'normalizes negated iteration_id' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload.dig(:not, :iteration_id)).to eq(iteration.id)
        end
      end

      context 'with OR iteration_id' do
        let(:filter_data) { { or: { iteration_id: iteration.id } } }

        it 'normalizes OR iteration_id' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload.dig(:or, :iteration_id)).to eq(iteration.id)
        end
      end
    end

    context 'with iteration_cadence_id filter' do
      let(:filter_data) { { iteration_cadence_id: iteration_cadence.id } }

      it 'converts iteration_cadence_id to iteration_cadence_ids (plural)' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload[:iteration_cadence_ids]).to eq(iteration_cadence.id)
        expect(result.payload).not_to have_key(:iteration_cadence_id)
      end
    end

    context 'with status filter' do
      context 'when status is provided as an object with ID' do
        context 'when status is a custom status' do
          let(:filter_data) { { status: status } }

          it 'normalizes status with ID, input format, and custom: true', :aggregate_failures do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:status]).to eq(
              id: status.id,
              input_format: :id,
              custom: true
            )
          end
        end

        context 'when status is a system-defined status' do
          let_it_be(:group_without_custom_statuses) { create(:group) }

          let(:container) { group_without_custom_statuses }
          let(:system_defined_status) { WorkItems::Statuses::SystemDefined::Status.find_by_name('Done') }
          let(:filter_data) { { status: system_defined_status } }

          it 'normalizes status with ID, input format, and custom: false', :aggregate_failures do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:status]).to eq(
              id: system_defined_status.id,
              input_format: :id,
              custom: false
            )
          end
        end
      end

      context 'when status is provided by name' do
        let(:filter_data) { { status: { name: 'In Progress' } } }

        it 'finds status by name and normalizes with ID, input format, and custom flag' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload[:status]).to eq(
            id: status.id,
            input_format: :name,
            custom: true
          )
        end

        context 'when the status resolves to a system-defined status' do
          let_it_be(:group_without_custom_statuses) { create(:group) }

          let(:container) { group_without_custom_statuses }
          let(:system_defined_status) { WorkItems::Statuses::SystemDefined::Status.find_by_name('Done') }
          let(:filter_data) { { status: { name: 'Done' } } }

          it 'finds status by name and normalizes with custom: false', :aggregate_failures do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:status]).to eq(
              id: system_defined_status.id,
              input_format: :name,
              custom: false
            )
          end
        end

        context 'when status name does not exist' do
          let(:filter_data) { { status: { name: 'NonExistent Status' } } }

          it 'does not set status filter' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload).not_to have_key(:status)
          end
        end

        context 'when status name has different casing' do
          let(:filter_data) { { status: { name: 'in progress' } } }

          it 'finds status case-insensitively' do
            result = service.execute

            expect(result).to be_success
            expect(result.payload[:status]).to eq(
              id: status.id,
              input_format: :name,
              custom: true
            )
          end
        end
      end

      context 'when status is provided as a hash without name' do
        let(:filter_data) { { status: { id: status.id } } }

        it 'does not set status filter' do
          result = service.execute

          expect(result).to be_success
          expect(result.payload).not_to have_key(:status)
        end
      end
    end

    context 'with combined FOSS and EE filters' do
      let(:filter_data) do
        {
          issue_types: ['ISSUE'],
          assignee_usernames: ['alice'],
          custom_field: [
            {
              custom_field_id: custom_field.id,
              selected_option_ids: [custom_field_option1.id]
            }
          ],
          iteration_id: iteration.id,
          status: status
        }
      end

      let_it_be(:user_alice) { create(:user, username: 'alice') }

      it 'normalizes all filters correctly' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to include(
          issue_types: ['ISSUE'],
          assignee_ids: [user_alice.id],
          iteration_id: iteration.id
        )
        expect(result.payload[:custom_field]).to eq([
          {
            custom_field_id: custom_field.id.to_s,
            selected_option_ids: [custom_field_option1.id.to_s]
          }
        ])
        expect(result.payload[:status]).to eq(
          id: status.id,
          input_format: :id,
          custom: true
        )
      end
    end

    context 'when an ArgumentError is raised during normalization' do
      let(:filter_data) { { custom_field: [{ custom_field_id: custom_field.id }] } }

      before do
        allow(service).to receive(:normalize_custom_field_entries).and_raise(ArgumentError.new('Example Error'))
      end

      it 'returns an error response' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to eq('Example Error')
      end
    end
  end
end
