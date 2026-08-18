# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Status, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:target_group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:target_project) { create(:project, group: target_group) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project) }
  let_it_be_with_reload(:target_work_item) { create(:work_item, project: target_project) }
  let_it_be(:current_status) { create(:work_item_current_status, work_item: work_item, status: status) }
  let_it_be(:status) { build(:work_item_system_defined_status, :to_do) }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: {}
    )
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  shared_examples "does not create current status record" do
    it { expect { callback.after_save }.not_to change { target_work_item.current_status } }
  end

  shared_examples "creates current status record and assigns correct status" do
    it "creates a current status record" do
      expect { callback.after_save }.to change { target_work_item.current_status }
    end

    it "assigns the correct status" do
      callback.after_save

      expect(target_work_item.current_status.status).to eq(target_status)
    end
  end

  shared_examples "does not call the StatusMatcherService" do
    it "does not intialize the service" do
      expect(::WorkItems::Widgets::Statuses::StatusMatcherService).not_to receive(:new)
      callback.after_save
    end
  end

  describe '#after_save' do
    context "when the feature is disabled" do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like "does not create current status record"
    end

    context "when target_work_item does not have a status widget" do
      let_it_be(:target_work_item) { create(:work_item, :objective, project: target_project) }

      it_behaves_like "does not create current status record"
    end

    context 'when all the conditions are meet' do
      context "when both lifecycles are system defined" do
        let(:target_status) { status }

        it_behaves_like "creates current status record and assigns correct status"

        it_behaves_like "does not call the StatusMatcherService"
      end

      context "when both lifecycles are custom and different" do
        let!(:lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: group) }
        let!(:target_lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: target_group) }
        let(:status) { lifecycle.default_open_status }
        let(:target_status) { target_lifecycle.default_open_status }
        let(:status_matcher_service) { instance_double(::WorkItems::Widgets::Statuses::StatusMatcherService) }

        context "when current status for work item exist" do
          before do
            work_item.current_status.status = status
            work_item.current_status.save!
          end

          it_behaves_like "creates current status record and assigns correct status"

          it "calls the StatusMatcherService" do
            expect(::WorkItems::Widgets::Statuses::StatusMatcherService).to receive(:new).with(status,
              target_lifecycle).and_return(status_matcher_service)
            expect(status_matcher_service).to receive(:find_fallback).and_return(target_status)

            callback.after_save
          end
        end

        context "when work item does not have a current_status record" do
          before do
            work_item.current_status.destroy!
          end

          it_behaves_like "creates current status record and assigns correct status"
        end
      end

      context "when both lifecycles are custom and the same" do
        let_it_be(:target_project) { create(:project, group: group) }
        let_it_be_with_reload(:target_work_item) { create(:work_item, project: target_project) }
        let!(:lifecycle) { create(:work_item_custom_lifecycle, :for_issues, namespace: group) }
        let(:status) { lifecycle.default_open_status }
        let(:target_status) { status }

        before do
          work_item.current_status.status = status
          work_item.current_status.save!
        end

        it_behaves_like "creates current status record and assigns correct status"

        it_behaves_like "does not call the StatusMatcherService"
      end

      context "when work_item and target_work_item have different states" do
        context "when work_item is closed and target work item is open" do
          let_it_be(:status) { build(:work_item_system_defined_status, :done) }
          let(:target_status) { build(:work_item_system_defined_status, :to_do) }

          before do
            work_item.close!
          end

          it_behaves_like "creates current status record and assigns correct status"

          it_behaves_like "does not call the StatusMatcherService"
        end

        context "when work_item is open and target work item is closed" do
          let(:target_status) { build(:work_item_system_defined_status, :done) }

          before do
            target_work_item.close!
          end

          it_behaves_like "creates current status record and assigns correct status"
          it_behaves_like "does not call the StatusMatcherService"
        end

        context "when work_item is open and target work item is duplicated" do
          let(:target_status) { build(:work_item_system_defined_status, :duplicate) }

          before do
            target_work_item.duplicated_to = create(:work_item, project: target_project)
            target_work_item.close!
          end

          it_behaves_like "creates current status record and assigns correct status"
          it_behaves_like "does not call the StatusMatcherService"
        end
      end
    end
  end

  describe "#post_move_cleanup" do
    it 'removes original work item current_status' do
      expect { callback.post_move_cleanup }.to change { work_item.reload.current_status }.to(nil)
    end
  end
end
