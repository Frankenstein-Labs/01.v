# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Statuses::BulkStatusUpdater, feature_category: :team_planning do
  let_it_be_with_reload(:old_group) { create(:group) }
  let_it_be_with_reload(:new_group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: old_group) }

  let_it_be(:system_to_do) { build_stubbed(:work_item_system_defined_status, :to_do) }
  let_it_be(:system_in_progress) { build_stubbed(:work_item_system_defined_status, :in_progress) }
  let_it_be(:system_done) { build_stubbed(:work_item_system_defined_status, :done) }
  let_it_be(:system_wont_do) { build_stubbed(:work_item_system_defined_status, :wont_do) }
  let_it_be(:system_duplicate) { build_stubbed(:work_item_system_defined_status, :duplicate) }

  let(:namespace_ids) { [project.project_namespace_id] }
  let(:old_lifecycle) { build(:work_item_system_defined_lifecycle) }

  subject(:updater) { described_class.new(status_mapping, old_lifecycle, namespace_ids) }

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe '#execute' do
    context 'with empty status mapping' do
      let(:status_mapping) { {} }

      it 'does not execute the query' do
        expect(WorkItems::Statuses::CurrentStatus).not_to receive(:upsert_all)

        updater.execute
      end
    end

    context 'with nil namespace_id' do
      let(:status_mapping) { { a: 1 } }
      let(:namespace_id) { nil }

      it 'does not execute the query' do
        expect(WorkItems::Statuses::CurrentStatus).not_to receive(:upsert_all)

        updater.execute
      end
    end

    context 'with valid status mapping' do
      context "for updating system_defined statuses to custom statuses" do
        let_it_be(:custom_to_do) { create(:work_item_custom_status, :open, namespace: new_group) }
        let_it_be(:custom_done) { create(:work_item_custom_status, :closed, namespace: new_group) }
        let_it_be(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: new_group) }
        let_it_be(:custom_in_progress) do
          create(:work_item_custom_status, category: :in_progress,
            converted_from_system_defined_status_identifier: system_in_progress.id, namespace: new_group)
        end

        let(:status_mapping) do
          {
            system_to_do => custom_to_do,
            system_in_progress => custom_in_progress,
            system_done => custom_done,
            system_wont_do => custom_canceled,
            system_duplicate => custom_canceled
          }
        end

        let_it_be(:work_item1) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: system_to_do)
          end
        end

        let_it_be(:work_item2) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: system_in_progress)
          end
        end

        let_it_be(:work_item3) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: system_done)
          end
        end

        let_it_be(:work_item4) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: system_wont_do)
          end
        end

        context "when current status exists for all work items" do
          it "updates the statuses of work items based on the status mapping" do
            expect { updater.execute }
              .to change { work_item1.current_status.reload.status }.from(system_to_do).to(custom_to_do)
              .and change { work_item2.current_status.reload.status }.from(system_in_progress).to(custom_in_progress)
              .and change { work_item3.current_status.reload.status }.from(system_done).to(custom_done)
              .and change { work_item4.current_status.reload.status }.from(system_wont_do).to(custom_canceled)
          end
        end

        context "when current status does not exist for some of the work items" do
          let_it_be(:work_item5) { create(:work_item, project: project) }
          let_it_be(:work_item6) { create(:work_item, :closed, project: project) }
          let_it_be(:work_item7) { create(:work_item, :closed_as_duplicate, project: project) }

          it "updates the statuses of work items based on the status mapping" do
            expect { updater.execute }
              .to change { work_item5.reload.current_status&.status }.from(nil).to(custom_to_do)
              .and change { work_item6.reload.current_status&.status }.from(nil).to(custom_done)
              .and change { work_item7.reload.current_status&.status }.from(nil).to(custom_canceled)
          end
        end

        context "when there are other work_items in another namespace" do
          let_it_be(:other_project) { create(:project) }
          let_it_be(:work_item5) { create(:work_item, project: other_project) }
          let_it_be(:work_item6) { create(:work_item, project: other_project) }

          it "does not update the work items" do
            expect { updater.execute }
              .to not_change { work_item5.reload.current_status }
              .and not_change { work_item6.reload.current_status }
          end
        end
      end

      context "for updating custom statuses to system_defined statuses" do
        let_it_be(:custom_to_do) { create(:work_item_custom_status, :open, namespace: old_group) }
        let_it_be(:custom_done) { create(:work_item_custom_status, :closed, namespace: old_group) }
        let_it_be(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: old_group) }
        let_it_be(:custom_in_progress) do
          create(:work_item_custom_status, category: :in_progress,
            converted_from_system_defined_status_identifier: system_in_progress.id, namespace: old_group)
        end

        let(:status_mapping) do
          {
            custom_to_do => system_to_do,
            custom_in_progress => system_in_progress,
            custom_done => system_done,
            custom_canceled => system_wont_do
          }
        end

        let!(:old_lifecycle) do
          create(:work_item_custom_lifecycle, :for_issues,
            namespace: old_group,
            statuses: [custom_to_do, custom_in_progress, custom_done, custom_canceled],
            default_open_status: custom_to_do,
            default_closed_status: custom_done,
            default_duplicate_status: custom_canceled
          )
        end

        let!(:work_item1) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: custom_to_do)
          end
        end

        let!(:work_item2) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: custom_in_progress)
          end
        end

        let!(:work_item3) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: custom_done)
          end
        end

        let!(:work_item4) do
          create(:work_item, project: project) do |work_item|
            create(:work_item_current_status, work_item: work_item, status: custom_canceled)
          end
        end

        context "when current status exists for all work items" do
          it "updates the statuses of work items based on the status mapping" do
            project.namespace = new_group
            project.save!

            expect { updater.execute }
              .to change { work_item1.current_status.reload.status }.from(custom_to_do).to(system_to_do)
              .and change { work_item2.current_status.reload.status }.from(custom_in_progress).to(system_in_progress)
              .and change { work_item3.current_status.reload.status }.from(custom_done).to(system_done)
              .and change { work_item4.current_status.reload.status }.from(custom_canceled).to(system_wont_do)
          end
        end

        context "when current status does not exist for some of the work items" do
          let_it_be_with_reload(:work_item5) { create(:work_item, project: project) }
          let_it_be_with_reload(:work_item6) { create(:work_item, :closed, project: project) }
          let_it_be_with_reload(:work_item7) { create(:work_item, :closed_as_duplicate, project: project) }

          it "updates the statuses of work items based on the status mapping" do
            project.namespace = new_group
            project.save!

            expect { updater.execute }
              .to change { work_item5.reload.current_status&.status }.from(nil).to(system_to_do)
              .and change { work_item6.reload.current_status&.status }.from(nil).to(system_done)
              .and change { work_item7.reload.current_status&.status }.from(nil).to(system_wont_do)
          end
        end

        context "when current status exists and have converted status" do
          # we need to skip validation as we want to test the updates with converted status
          let_it_be_with_reload(:work_item5) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item, status: system_to_do).save!(validate: false)
            end
          end

          let_it_be_with_reload(:work_item6) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item,
                status: system_in_progress).save!(validate: false)
            end
          end

          let_it_be_with_reload(:work_item7) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item, status: system_done).save!(validate: false)
            end
          end

          it "updates the statuses of work items based on the status mapping" do
            expect(work_item5.current_status.status).to eq(custom_to_do)
            expect(work_item6.current_status.status).to eq(custom_in_progress)
            expect(work_item7.current_status.status).to eq(custom_done)

            project.namespace = new_group
            project.save!

            updater.execute

            expect(work_item5.reload.current_status.status).to eq(system_to_do)
            expect(work_item6.reload.current_status.status).to eq(system_in_progress)
            expect(work_item7.reload.current_status.status).to eq(system_done)
          end
        end
      end

      context "for updating custom statuses to custom statuses" do
        let_it_be(:custom_to_do) { create(:work_item_custom_status, :open, namespace: old_group) }
        let_it_be(:custom_done) { create(:work_item_custom_status, :closed, namespace: old_group) }
        let_it_be(:custom_canceled) { create(:work_item_custom_status, :duplicate, namespace: old_group) }
        let_it_be(:custom_in_progress) do
          create(:work_item_custom_status, category: :in_progress,
            converted_from_system_defined_status_identifier: system_in_progress.id, namespace: old_group)
        end

        let_it_be(:custom_to_do2) { create(:work_item_custom_status, :open, namespace: new_group) }
        let_it_be(:custom_done2) { create(:work_item_custom_status, :closed, namespace: new_group) }
        let_it_be(:custom_canceled2) { create(:work_item_custom_status, :duplicate, namespace: new_group) }
        let_it_be(:custom_in_progress2) do
          create(:work_item_custom_status, category: :in_progress,
            converted_from_system_defined_status_identifier: system_in_progress.id, namespace: new_group)
        end

        let!(:new_lifecycle) do
          create(:work_item_custom_lifecycle, :for_issues,
            namespace: new_group,
            statuses: [custom_to_do2, custom_in_progress2, custom_done2, custom_canceled2],
            default_open_status: custom_to_do2,
            default_closed_status: custom_done2,
            default_duplicate_status: custom_canceled2
          )
        end

        let!(:old_lifecycle) do
          create(:work_item_custom_lifecycle, :for_issues,
            namespace: old_group,
            statuses: [custom_to_do, custom_in_progress, custom_done, custom_canceled],
            default_open_status: custom_to_do,
            default_closed_status: custom_done,
            default_duplicate_status: custom_canceled
          )
        end

        let(:status_mapping) do
          {
            custom_to_do => custom_to_do2,
            custom_in_progress => custom_in_progress2,
            custom_done => custom_done2,
            custom_canceled => custom_canceled2
          }
        end

        context "when current status exists for all work items" do
          let!(:work_item1) do
            create(:work_item, project: project) do |work_item|
              create(:work_item_current_status, work_item: work_item, status: custom_to_do)
            end
          end

          let!(:work_item2) do
            create(:work_item, project: project) do |work_item|
              create(:work_item_current_status, work_item: work_item, status: custom_in_progress)
            end
          end

          let!(:work_item3) do
            create(:work_item, project: project) do |work_item|
              create(:work_item_current_status, work_item: work_item, status: custom_done)
            end
          end

          let!(:work_item4) do
            create(:work_item, project: project) do |work_item|
              create(:work_item_current_status, work_item: work_item, status: custom_canceled)
            end
          end

          it "updates the statuses of work items based on the status mapping" do
            project.namespace = new_group
            project.save!

            expect { updater.execute }
              .to change { work_item1.current_status.reload.status }.from(custom_to_do).to(custom_to_do2)
              .and change { work_item2.current_status.reload.status }.from(custom_in_progress).to(custom_in_progress2)
              .and change { work_item3.current_status.reload.status }.from(custom_done).to(custom_done2)
              .and change { work_item4.current_status.reload.status }.from(custom_canceled).to(custom_canceled2)
          end
        end

        context "when current status does not exist for some of the work items" do
          let_it_be_with_reload(:work_item5) { create(:work_item, project: project) }
          let_it_be_with_reload(:work_item6) { create(:work_item, :closed, project: project) }
          let_it_be_with_reload(:work_item7) { create(:work_item, :closed_as_duplicate, project: project) }

          it "updates the statuses of work items based on the status mapping" do
            project.namespace = new_group
            project.save!

            expect { updater.execute }
              .to change { work_item5.reload.current_status&.status }.from(nil).to(custom_to_do2)
              .and change { work_item6.reload.current_status&.status }.from(nil).to(custom_done2)
              .and change { work_item7.reload.current_status&.status }.from(nil).to(custom_canceled2)
          end
        end

        context "when current status exists and have converted status" do
          # we need to skip validation as we want to test the updates with converted status
          let_it_be_with_reload(:work_item5) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item, status: system_to_do).save!(validate: false)
            end
          end

          let_it_be_with_reload(:work_item6) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item,
                status: system_in_progress).save!(validate: false)
            end
          end

          let_it_be_with_reload(:work_item7) do
            create(:work_item, project: project) do |work_item|
              build(:work_item_current_status, work_item: work_item, status: system_done).save!(validate: false)
            end
          end

          it "updates the statuses of work items based on the status mapping" do
            expect(work_item5.current_status.status).to eq(custom_to_do)
            expect(work_item6.current_status.status).to eq(custom_in_progress)
            expect(work_item7.current_status.status).to eq(custom_done)

            project.namespace = new_group
            project.save!

            updater.execute

            expect(work_item5.reload.current_status.status).to eq(custom_to_do2)
            expect(work_item6.reload.current_status.status).to eq(custom_in_progress2)
            expect(work_item7.reload.current_status.status).to eq(custom_done2)
          end
        end
      end
    end
  end
end
