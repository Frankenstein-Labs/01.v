# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::CreateService, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let(:user) { create(:user, maintainer_of: group) }

  let_it_be(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }
  let_it_be(:system_defined_in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_defined_wont_do_status) { build(:work_item_system_defined_status, :wont_do) }

  let(:lifecycle_name) { 'New Lifecycle' }
  let(:params) do
    {
      name: lifecycle_name,
      statuses: [
        {
          name: "New To do",
          color: "#000000",
          category: "to_do"
        },
        {
          name: "New Done",
          color: "#000000",
          category: "done"
        },
        {
          name: "New Duplicate",
          color: "#000000",
          category: "canceled"
        }
      ],
      default_open_status_index: 0,
      default_closed_status_index: 1,
      default_duplicate_status_index: 2
    }
  end

  subject(:result) do
    described_class.new(container: group, current_user: user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    let(:lifecycle) { result.payload[:lifecycle] }

    it_behaves_like 'lifecycle service creates custom lifecycle'

    it 'sets default statuses correctly' do
      expect(lifecycle.default_open_status.name).to eq("New To do")
      expect(lifecycle.default_closed_status.name).to eq("New Done")
      expect(lifecycle.default_duplicate_status.name).to eq("New Duplicate")
    end

    context 'with statuses not ordered by category' do
      let(:params) do
        {
          name: lifecycle_name,
          statuses: [
            {
              name: "New To do",
              color: "#000000",
              category: "to_do"
            },
            {
              name: "New Duplicate",
              color: "#000000",
              category: "canceled"
            },
            {
              name: "New Done",
              color: "#000000",
              category: "done"
            }
          ],
          default_open_status_index: 0,
          default_closed_status_index: 2,
          default_duplicate_status_index: 1
        }
      end

      it 'sets statuses in correct order' do
        expect(lifecycle.ordered_statuses.map(&:name)).to eq(["New To do", "New Done", "New Duplicate"])
      end
    end

    it 'converts existing system-defined lifecycle to custom lifecycle' do
      expect { result }.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(2)

      first_lifecycle = group.reset.lifecycles.first
      expect(first_lifecycle.name).to eq(system_defined_lifecycle.name)
      expect(first_lifecycle.statuses.pluck(:name)).to contain_exactly(
        system_defined_lifecycle.default_open_status.name,
        system_defined_in_progress_status.name,
        system_defined_lifecycle.default_closed_status.name,
        system_defined_wont_do_status.name,
        system_defined_lifecycle.default_duplicate_status.name
      )

      expect(first_lifecycle.statuses.pluck(:converted_from_system_defined_status_identifier))
        .to contain_exactly(1, 2, 3, 4, 5)
    end

    it 'tracks status creation events for the new statuses' do
      expect { result }
        .to trigger_internal_events('create_custom_status_in_group_settings')
        .with(user: user, namespace: group, additional_properties: { label: be_a(String) })
        .exactly(3).times
    end

    it 'tracks lifecycle creation event', :clean_gitlab_redis_shared_state do
      expect { result }
        .to trigger_internal_events('create_custom_lifecycle')
        .with(user: user, namespace: group)
        .and increment_usage_metrics(
          'redis_hll_counters.count_distinct_namespace_id_from_create_custom_lifecycle_monthly',
          'redis_hll_counters.count_distinct_namespace_id_from_create_custom_lifecycle_weekly',
          'counts.count_total_create_custom_lifecycle_monthly',
          'counts.count_total_create_custom_lifecycle_weekly',
          'counts.count_total_create_custom_lifecycle'
        )
    end

    context 'when params are missing or are invalid' do
      let(:status_validation_error) do
        <<~ERROR.squish
          Default open status can't be blank,
          Default closed status can't be blank,
          Default duplicate status can't be blank
        ERROR
      end

      let(:dup_status_validation_error) { "Default duplicate status can't be blank" }

      where(:scenario, :param_changes, :expected_error_message) do
        'blank name'                | { name: '' }                            | "Name can't be blank"
        'nil name'                  | { name: nil }                           | "Name can't be blank"
        'empty statuses'            | { statuses: [] }                        | ref(:status_validation_error)
        'nil statuses'              | { statuses: nil }                       | ref(:status_validation_error)
        'missing open status index' | { default_open_status_index: nil }      | "Default open status can't be blank"
        'invalid open status index' | { default_open_status_index: 99 }       | "Default open status can't be blank"
        'missing closed status'     | { default_closed_status_index: nil }    | "Default closed status can't be blank"
        'missing duplicate status'  | { default_duplicate_status_index: nil } | ref(:dup_status_validation_error)
      end

      with_them do
        let(:params) do
          super().merge(param_changes)
        end

        it_behaves_like 'lifecycle service returns validation error'
        it_behaves_like 'lifecycle service does not create custom lifecycle'
      end
    end

    context 'when attempting to exceed status limit' do
      let(:params) do
        super().merge(statuses: [
          {
            name: "New To do",
            color: "#000000",
            category: "to_do"
          },
          {
            name: "New Done",
            color: "#000000",
            category: "done"
          },
          {
            name: "New Duplicate",
            color: "#000000",
            category: "canceled"
          },
          {
            named: "Exceeding limit status",
            color: "#000000",
            category: "canceled"
          }
        ])
      end

      let(:expected_error_message) { 'Lifecycle can only have a maximum of 3 statuses' }

      before do
        stub_const("WorkItems::Statuses::Custom::Lifecycle::MAX_STATUSES_PER_LIFECYCLE", 3)
      end

      it_behaves_like 'lifecycle service returns validation error'
    end

    context 'when another custom lifecycle exists' do
      let_it_be(:existing_lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

      context 'when passing existing statuses' do
        let(:params) do
          super().merge(statuses: [
            { id: existing_lifecycle.default_open_status.to_global_id },
            { id: existing_lifecycle.default_closed_status.to_global_id },
            { id: existing_lifecycle.default_duplicate_status.to_global_id }
          ])
        end

        it_behaves_like 'lifecycle service creates custom lifecycle'

        it 'sets default statuses correctly' do
          expect(lifecycle.default_open_status.name).to eq(existing_lifecycle.default_open_status.name)
          expect(lifecycle.default_closed_status.name).to eq(existing_lifecycle.default_closed_status.name)
          expect(lifecycle.default_duplicate_status.name).to eq(existing_lifecycle.default_duplicate_status.name)
        end
      end

      context 'when passing existing and new statuses' do
        let(:params) do
          super().merge(statuses: [
            {
              id: existing_lifecycle.default_open_status.to_global_id,
              color: "#ffffff"
            },
            {
              name: "Completed",
              color: "#000000",
              category: "done"
            },
            { id: existing_lifecycle.default_duplicate_status.to_global_id }
          ])
        end

        it_behaves_like 'lifecycle service creates custom lifecycle'

        it 'tracks status creation event for the new status' do
          expect { result }
            .to trigger_internal_events('create_custom_status_in_group_settings')
            .with(user: user, namespace: group, additional_properties: { label: 'done' })
            .once
        end

        it 'tracks status update event for the updated status' do
          expect { result }
            .to trigger_internal_events('update_custom_status_in_group_settings')
            .with(user: user, namespace: group, additional_properties: { label: 'to_do' })
            .once
        end

        it 'updates existing status' do
          expect(lifecycle.default_open_status.color).to eq("#ffffff")
        end

        it 'sets default statuses correctly' do
          expect(lifecycle.default_open_status.name).to eq(existing_lifecycle.default_open_status.name)
          expect(lifecycle.default_closed_status.name).to eq("Completed")
          expect(lifecycle.default_duplicate_status.name).to eq(existing_lifecycle.default_duplicate_status.name)
        end
      end
    end

    context 'when lifecycle with same name already exists' do
      let!(:existing_lifecycle) do
        create(:work_item_custom_lifecycle, name: lifecycle_name, namespace: group)
      end

      let(:expected_error_message) { 'Name has already been taken' }

      it_behaves_like 'lifecycle service returns validation error'
      it_behaves_like 'lifecycle service does not create custom lifecycle'

      context 'and it is the system-defined lifecycle' do
        let(:lifecycle_name) { system_defined_lifecycle.name }

        it_behaves_like 'lifecycle service returns validation error'
        it_behaves_like 'lifecycle service does not create custom lifecycle'
      end
    end

    context 'when provided status belongs to other root namespace' do
      let!(:other_custom_lifecycle) do
        create(:work_item_custom_lifecycle, namespace: other_group)
      end

      let(:params) do
        super().merge(statuses: [
          {
            name: "New To do",
            color: "#000000",
            category: "to_do"
          },
          {
            name: "New Done",
            color: "#000000",
            category: "done"
          },
          {
            name: "New Duplicate",
            color: "#000000",
            category: "canceled"
          },
          { id: other_custom_lifecycle.default_open_status.to_global_id }
        ])
      end

      let(:expected_error_message) do
        "Status '#{other_custom_lifecycle.default_open_status.name}' doesn't belong to this namespace."
      end

      it_behaves_like 'lifecycle service returns validation error'
    end
  end
end
