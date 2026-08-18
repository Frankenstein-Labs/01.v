# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Lifecycles::DeleteService, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, maintainer_of: group) }

  let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }
  let(:lifecycle_id) { lifecycle.id }

  let(:params) { { id: lifecycle.to_gid } }

  subject(:result) do
    described_class.new(container: group, current_user: user, params: params).execute
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  RSpec.shared_examples 'deletes lifecycle but preserves used statuses' do
    it 'deletes lifecycle and only statuses not in use' do
      expect do
        result
      end.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(-1)
        .and change { WorkItems::Statuses::Custom::Status.count }.by(-2)

      expect(custom_to_do_status.reload).to be_persisted
      expect(result.payload[:lifecycle].id).to eq(lifecycle_id)
      expect(result.payload[:lifecycle]).not_to be_persisted
    end

    it_behaves_like 'tracks lifecycle delete event'
  end

  RSpec.shared_examples 'tracks lifecycle delete event' do
    it 'tracks lifecycle delete event', :clean_gitlab_redis_shared_state do
      expect { result }
        .to trigger_internal_events('delete_custom_lifecycle')
        .with(user: user, namespace: group)
        .and increment_usage_metrics(
          'redis_hll_counters.count_distinct_namespace_id_from_delete_custom_lifecycle_monthly',
          'redis_hll_counters.count_distinct_namespace_id_from_delete_custom_lifecycle_weekly',
          'counts.count_total_delete_custom_lifecycle_monthly',
          'counts.count_total_delete_custom_lifecycle_weekly',
          'counts.count_total_delete_custom_lifecycle'
        )
    end
  end

  describe '#execute' do
    context 'when custom lifecycle exists' do
      let_it_be(:custom_to_do_status) { create(:work_item_custom_status, :to_do, namespace: group) }

      let_it_be(:lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group, default_open_status: custom_to_do_status)
      end

      it 'deletes lifecycle and its statuses' do
        expect do
          result
        end.to change { WorkItems::Statuses::Custom::Lifecycle.count }.by(-1)
          .and change { WorkItems::Statuses::Custom::Status.count }.by(-3)

        expect(result.payload[:lifecycle].id).to eq(lifecycle_id)
        expect(result.payload[:lifecycle]).not_to be_persisted
      end

      it 'returns success response with the deleted lifecycle' do
        expect(result).to be_success
        expect(result.payload[:lifecycle]).to eq(lifecycle)
      end

      it_behaves_like 'tracks lifecycle delete event'

      context 'when statuses are in use' do
        context 'when status is used in a different lifecycle' do
          let_it_be(:custom_lifecycle_2) do
            create(:work_item_custom_lifecycle, namespace: group, default_open_status: custom_to_do_status)
          end

          it_behaves_like 'deletes lifecycle but preserves used statuses'
        end

        context 'when status is used in a mapping' do
          let_it_be(:custom_to_do_status_2) do
            create(:work_item_custom_status, :to_do, namespace: group)
          end

          let_it_be(:custom_status_mapping) do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: issue_work_item_type,
              old_status: custom_to_do_status,
              new_status: custom_to_do_status_2
            )
          end

          it_behaves_like 'deletes lifecycle but preserves used statuses'
        end
      end

      context 'when lifecycle is in use' do
        let!(:type_custom_lifecycle) do
          create(:work_item_type_custom_lifecycle,
            work_item_type: issue_work_item_type,
            lifecycle: lifecycle
          )
        end

        let(:expected_error_message) do
          'Cannot delete lifecycle because it is currently in use.'
        end

        it 'does not delete lifecycle and its statuses' do
          expect do
            result
          end.to not_change { WorkItems::Statuses::Custom::Lifecycle.count }
            .and not_change { WorkItems::Statuses::Custom::Status.count }
        end

        it 'does not trigger internal events' do
          expect { result }.not_to trigger_internal_events
        end

        it_behaves_like 'lifecycle service returns validation error'
      end
    end

    context 'when custom lifecycle does not exist' do
      let(:lifecycle) { build(:work_item_system_defined_lifecycle) }

      let(:expected_error_message) do
        'Invalid lifecycle type. Only custom lifecycles can be deleted.'
      end

      it_behaves_like 'lifecycle service returns validation error'

      it 'does not trigger internal events' do
        expect { result }.not_to trigger_internal_events
      end

      context 'with invalid lifecycle ID' do
        let(:params) { { id: "gid://gitlab/WorkItems::Statuses::Custom::Lifecycle/0" } }

        let(:expected_error_message) do
          "Couldn't find WorkItems::Statuses::Custom::Lifecycle with 'id'=0"
        end

        it_behaves_like 'lifecycle service returns validation error'
      end
    end

    context 'when lifecycle belongs to a different namespace' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: other_group) }

      let(:expected_error_message) { "You don't have permission to delete this lifecycle." }

      it 'does not delete lifecycle and its statuses' do
        expect do
          result
        end.to not_change { WorkItems::Statuses::Custom::Lifecycle.count }
          .and not_change { WorkItems::Statuses::Custom::Status.count }
      end

      it 'does not trigger internal events' do
        expect { result }.not_to trigger_internal_events
      end

      it_behaves_like 'lifecycle service returns validation error'
    end
  end
end
