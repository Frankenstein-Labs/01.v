# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::CurrentStatus, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be_with_refind(:task_work_item) { create(:work_item, :task, project: project) }
  let_it_be_with_refind(:issue_work_item) { create(:work_item, :issue, project: project) }
  let_it_be_with_refind(:epic_work_item) { create(:work_item, :epic, project: project) }

  let(:work_item) { task_work_item }

  let_it_be(:system_defined_status) { build(:work_item_system_defined_status) }
  let_it_be(:custom_status) { create(:work_item_custom_status) }

  let_it_be(:expected_error_key) { :system_defined_status }
  let_it_be(:expected_error_message) { 'not provided or references non-existent system defined status' }

  subject(:current_status) { build_stubbed(:work_item_current_status, work_item: work_item) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples 'a valid object' do
    it 'is valid' do
      expect(current_status).to be_valid
    end
  end

  shared_examples 'an invalid object' do
    it 'is invalid' do
      expect(current_status).to be_invalid
      expect(current_status.errors[expected_error_key]).to include(expected_error_message)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
    it { is_expected.to belong_to(:custom_status).class_name('WorkItems::Statuses::Custom::Status').optional }

    describe 'belongs_to_fixed_items :system_defined_status' do
      # We don't have a matcher to test this in one line yet.
      # So let's check whether generated methods are present
      # and behave as expected.
      it { is_expected.to respond_to(:system_defined_status) }
      it { is_expected.to respond_to(:system_defined_status=) }
      it { is_expected.to respond_to(:system_defined_status_id) }
      it { is_expected.to respond_to(:system_defined_status_id=) }

      it 'returns correct association object' do
        expect(current_status.system_defined_status).to be_a(WorkItems::Statuses::SystemDefined::Status)
        expect(current_status.system_defined_status.id).to eq(1)
      end

      context 'when association id is changed' do
        let(:status_id) { 2 }

        before do
          current_status.system_defined_status_id = status_id
        end

        it 'returns correct association object' do
          expect(current_status.system_defined_status).to be_a(WorkItems::Statuses::SystemDefined::Status)
          expect(current_status.system_defined_status.id).to eq(status_id)
        end
      end
    end
  end

  describe 'validations' do
    context 'with task work item' do
      it { is_expected.to be_valid }
    end

    context 'with issue work item' do
      let(:work_item) { issue_work_item }

      it { is_expected.to be_valid }
    end

    describe '#validate_status_exists' do
      shared_examples 'validates status exists' do
        context 'when custom status is enabled' do
          let_it_be(:expected_error_key) { :custom_status }
          let_it_be(:expected_error_message) { 'not provided or references non-existent custom status' }

          before do
            allow(current_status).to receive(:custom_status_enabled?).and_return(true)
          end

          context 'with system-defined status' do
            it_behaves_like 'an invalid object'
          end

          context 'with system-defined and custom status' do
            subject(:current_status) do
              build_stubbed(:work_item_current_status, :custom, system_defined_status_id: 1, work_item: work_item)
            end

            it_behaves_like 'a valid object'
          end

          context 'with only custom status' do
            subject(:current_status) do
              build_stubbed(:work_item_current_status, :custom, work_item: work_item)
            end

            it_behaves_like 'a valid object'
          end

          context 'without any status' do
            subject(:current_status) do
              build_stubbed(:work_item_current_status, custom_status: nil, system_defined_status: nil,
                work_item: work_item)
            end

            it_behaves_like 'an invalid object'
          end
        end

        context 'when custom status is not enabled' do
          context 'with system-defined status' do
            it_behaves_like 'a valid object'
          end

          context 'with system-defined and custom status' do
            subject(:current_status) do
              build_stubbed(:work_item_current_status, :custom, system_defined_status_id: 1, work_item: work_item)
            end

            it_behaves_like 'a valid object'
          end

          context 'with only custom status' do
            subject(:current_status) { build_stubbed(:work_item_current_status, :custom, work_item: work_item) }

            it_behaves_like 'an invalid object'
          end

          context 'without any status' do
            subject(:current_status) do
              build_stubbed(:work_item_current_status, custom_status: nil, system_defined_status: nil,
                work_item: work_item)
            end

            it_behaves_like 'an invalid object'
          end
        end
      end

      context 'with task work item' do
        it_behaves_like 'validates status exists'
      end

      context 'with issue work item' do
        let(:work_item) { issue_work_item }

        it_behaves_like 'validates status exists'
      end
    end

    describe '#validate_status_allowed_for_type' do
      let_it_be(:expected_error_message) { 'not allowed for this work item type' }

      context 'when system-defined status is present' do
        context 'when work item type has a lifecycle assigned' do
          context 'with task work item' do
            it_behaves_like 'a valid object'
          end

          context 'with issue work item' do
            let(:work_item) { issue_work_item }

            it_behaves_like 'a valid object'
          end
        end

        context 'when work item type does not have a lifecycle assigned' do
          let(:work_item) { epic_work_item }

          it_behaves_like 'an invalid object'
        end
      end

      context 'when custom status is present' do
        let_it_be(:expected_error_key) { :custom_status }

        shared_examples 'validates custom status for work item type' do
          subject(:current_status) { build_stubbed(:work_item_current_status, :custom, work_item: work_item) }

          context 'when custom status is enabled for the work item type' do
            before do
              allow(current_status).to receive(:custom_status_enabled?).and_return(true)
            end

            it_behaves_like 'a valid object'
          end

          context 'when custom status is not enabled for the work item type' do
            before do
              allow(current_status).to receive(:custom_status_enabled?).and_return(false)
              allow(current_status).to receive(:validate_status_allowed_for_type) do
                current_status.send(:validate_custom_status_allowed)
              end
            end

            it_behaves_like 'an invalid object'
          end
        end

        context 'with task work item' do
          it_behaves_like 'validates custom status for work item type'
        end

        context 'with issue work item' do
          let(:work_item) { issue_work_item }

          it_behaves_like 'validates custom status for work item type'
        end
      end
    end

    describe '#validate_custom_status_allowed_for_lifecycle' do
      shared_examples 'validates custom status for lifecycle' do
        let_it_be(:namespace) { group }
        let(:work_item_type) { work_item.work_item_type }

        let_it_be(:expected_error_key) { :custom_status }
        let_it_be(:expected_error_message) { 'is not allowed for this lifecycle' }

        let_it_be(:lifecycle) do
          create(:work_item_custom_lifecycle, namespace: group, default_open_status: custom_status)
        end

        before do
          create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type,
            namespace: namespace)

          allow(current_status).to receive(:custom_status_enabled?).and_call_original
        end

        context 'when custom status is allowed for lifecycle' do
          subject(:current_status) do
            build_stubbed(:work_item_current_status, :custom, custom_status: custom_status, work_item: work_item)
          end

          it 'is valid' do
            expect(current_status).to be_valid
          end
        end

        context 'when custom status is not allowed for lifecycle' do
          subject(:current_status) do
            build_stubbed(:work_item_current_status, :custom, work_item: work_item)
          end

          it 'is invalid' do
            expect(current_status).to be_invalid
            expect(current_status.errors[expected_error_key]).to include(expected_error_message)
          end
        end
      end

      context 'with task work item' do
        it_behaves_like 'validates custom status for lifecycle'
      end

      context 'with issue work item' do
        let(:work_item) { issue_work_item }

        it_behaves_like 'validates custom status for lifecycle'
      end
    end
  end

  describe 'database check constraint for status associations' do
    subject(:current_status) { build(:work_item_current_status, :system_defined, work_item: work_item) }

    context 'when system_defined_status_id is present' do
      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when custom_status_id is present' do
      subject(:current_status) { build(:work_item_current_status, :custom, work_item: work_item) }

      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when both system_defined_status_id and custom_status_id are present' do
      subject(:current_status) do
        build(:work_item_current_status, :custom, system_defined_status_id: 1, work_item: work_item)
      end

      it 'saves record' do
        expect { current_status.save!(validate: false) }.not_to raise_error
      end
    end

    context 'when neither system_defined_status_id nor custom_status_id are present' do
      subject(:current_status) do
        build(:work_item_current_status, custom_status: nil, system_defined_status: nil, work_item: work_item)
      end

      it 'raises error' do
        expect { current_status.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe 'database sharding key trigger' do
    subject(:current_status) { create(:work_item_current_status, work_item: work_item) }

    it 'sets namespace_id based on work item' do
      expect(current_status.reset.namespace_id).to eq(work_item.namespace_id)
    end
  end

  describe '#status' do
    context 'with system-defined status' do
      it 'returns system-defined status' do
        expect(current_status.status).to eq(current_status.system_defined_status)
      end

      context 'when custom lifecycle is present' do
        let!(:lifecycle) do
          create(:work_item_custom_lifecycle, namespace: group, work_item_types: [work_item.work_item_type])
        end

        let!(:mapped_custom_status) do
          lifecycle.statuses.find_by(
            converted_from_system_defined_status_identifier: current_status.system_defined_status_id
          )
        end

        it 'returns the custom status mapped to the system-defined status' do
          expect(current_status.status).to eq(mapped_custom_status)
        end
      end
    end

    context 'with custom status' do
      subject(:current_status) do
        build_stubbed(:work_item_current_status, :custom, work_item: work_item)
      end

      it 'returns custom status' do
        expect(current_status.status).to eq(current_status.custom_status)
      end

      context 'with status mappings' do
        let!(:custom_lifecycle) { create(:work_item_custom_lifecycle, :for_tasks, namespace: group) }
        let!(:old_custom_status) { custom_lifecycle.default_open_status }

        let_it_be(:new_custom_status) do
          create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: nil)
        end

        let_it_be(:another_new_status) do
          create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: nil)
        end

        subject(:current_status) do
          build(:work_item_current_status, :custom,
            custom_status: old_custom_status,
            work_item: work_item,
            updated_at: Time.current
          )
        end

        before do
          create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: new_custom_status)
          create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: another_new_status)
        end

        context 'when no mappings exist' do
          it 'returns the original custom status' do
            expect(current_status.status).to eq(old_custom_status)
          end
        end

        context 'when single mapping exists' do
          before do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status
            )
          end

          it 'returns the mapped status' do
            expect(current_status.status).to eq(new_custom_status)
          end

          context 'when current status has converted system-defined status' do
            subject(:current_status) do
              build(:work_item_current_status, :custom,
                system_defined_status_id: old_custom_status.converted_from_system_defined_status_identifier,
                custom_status_id: nil,
                work_item: work_item,
                updated_at: Time.current
              )
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end
        end

        context 'when mapping with valid_until exists' do
          before do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_until: 1.day.ago
            )
          end

          context 'when work item updated_at is covered by mapping' do
            before do
              current_status.updated_at = 2.days.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end

          context 'when work item updated_at is not covered by mapping' do
            before do
              current_status.updated_at = 1.hour.ago
            end

            it 'returns the original custom status' do
              expect(current_status.status).to eq(old_custom_status)
            end
          end
        end

        context 'when two sequential mappings exist' do
          before do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_until: 3.days.ago
            )

            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_from: 3.days.ago
            )
          end

          context 'when work item updated_at is covered by second mapping' do
            before do
              current_status.updated_at = 2.days.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end

          context 'when work item updated_at is covered by first mapping' do
            before do
              current_status.updated_at = 4.days.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end
        end

        context 'when mappings with gaps exist' do
          before do
            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_until: 7.days.ago
            )

            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: another_new_status,
              valid_from: 5.days.ago,
              valid_until: 3.days.ago
            )

            create(:work_item_custom_status_mapping,
              namespace: group,
              work_item_type: work_item.work_item_type,
              old_status: old_custom_status,
              new_status: new_custom_status,
              valid_from: 1.day.ago
            )
          end

          context 'when work item updated_at is covered by first mapping' do
            before do
              current_status.updated_at = 8.days.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end

          context 'when work item updated_at sits between the first two mappings' do
            before do
              current_status.updated_at = 6.days.ago
            end

            it 'returns the original custom status' do
              expect(current_status.status).to eq(old_custom_status)
            end
          end

          context 'when work item updated_at is covered by second mapping' do
            before do
              current_status.updated_at = 4.days.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(another_new_status)
            end
          end

          context 'when work item updated_at sits between the second two mappings' do
            before do
              current_status.updated_at = 2.days.ago
            end

            it 'returns the original custom status' do
              expect(current_status.status).to eq(old_custom_status)
            end
          end

          context 'when work item updated_at is covered by third mapping' do
            before do
              current_status.updated_at = 1.hour.ago
            end

            it 'returns the mapped status' do
              expect(current_status.status).to eq(new_custom_status)
            end
          end
        end

        context 'when no mappings exist for the specific combination' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:other_work_item_type) { create(:work_item_system_defined_type) }

          before do
            # Create mapping for different combination
            create(:work_item_custom_status_mapping,
              namespace: other_group,
              work_item_type: work_item.work_item_type,
              old_status: create(:work_item_custom_status, namespace: other_group),
              new_status: create(:work_item_custom_status, namespace: other_group)
            )
          end

          it 'returns the original custom status when namespace differs' do
            expect(current_status.status).to eq(old_custom_status)
          end

          context 'when work_item_type differs' do
            let(:work_item) { create(:work_item, work_item_type: other_work_item_type, project: project) }

            it 'returns the original custom status' do
              expect(current_status.status).to eq(old_custom_status)
            end
          end
        end

        it 'uses SafeRequestStore to cache mappings' do
          allow(::Gitlab::SafeRequestStore).to receive(:fetch).and_call_original
          # regexp should match work_items:status_mappings:553
          expect(::Gitlab::SafeRequestStore).to receive(:fetch).with(
            /^work_items:status_mappings:\d+/
          ).and_call_original.once

          current_status.status
        end
      end
    end

    context 'with system-defined and custom status' do
      subject(:current_status) do
        build_stubbed(:work_item_current_status, :custom, system_defined_status_id: 1, work_item: work_item)
      end

      it 'returns custom status' do
        expect(current_status.status).to eq(current_status.custom_status)
      end
    end
  end

  describe '#status=' do
    let_it_be(:custom_status) { create(:work_item_custom_status) }

    subject(:current_status) do
      build_stubbed(:work_item_current_status, system_defined_status: nil, custom_status: nil)
    end

    context 'with system-defined status' do
      it 'sets system-defined status' do
        current_status.status = system_defined_status

        expect(current_status.system_defined_status_id).to eq(system_defined_status.id)
        expect(current_status.custom_status_id).to be_nil
      end

      context 'when custom status is set' do
        subject(:current_status) do
          build_stubbed(:work_item_current_status, system_defined_status: nil, custom_status: custom_status)
        end

        it 'sets custom status to nil' do
          current_status.status = system_defined_status

          expect(current_status.system_defined_status_id).to eq(system_defined_status.id)
          expect(current_status.custom_status_id).to be_nil
        end
      end
    end

    context 'with custom status' do
      it 'sets custom status' do
        current_status.status = custom_status

        expect(current_status.custom_status_id).to eq(custom_status.id)
        expect(current_status.system_defined_status_id).to be_nil
      end

      context 'when system-defined status is set' do
        subject(:current_status) do
          build_stubbed(:work_item_current_status, system_defined_status_id: 1, custom_status: nil)
        end

        it 'sets system-defined status to nil' do
          current_status.status = custom_status

          expect(current_status.custom_status_id).to eq(custom_status.id)
          expect(current_status.system_defined_status_id).to be_nil
        end
      end
    end

    context 'with nil' do
      it 'does not set any status' do
        current_status.status = nil

        expect(current_status.custom_status_id).to be_nil
        expect(current_status.system_defined_status_id).to be_nil
      end
    end
  end
end
