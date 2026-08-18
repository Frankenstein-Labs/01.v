# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Status, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }
  let_it_be_with_reload(:unsupported_work_item) { create(:work_item, :ticket, project: project) }

  let(:in_progress_status) { build(:work_item_system_defined_status, :in_progress) }
  let(:done_status) { build(:work_item_system_defined_status, :done) }
  let(:default_open_status) { build(:work_item_system_defined_status, :to_do) }
  let(:item) { work_item }
  let(:params) { {} }
  let(:status_update_service) { instance_double(WorkItems::Widgets::Statuses::UpdateService) }

  subject(:callback) { described_class.new(issuable: item, current_user: current_user, params: params) }

  before_all do
    project.add_reporter(current_user)
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  def work_item_status
    item.reload.current_status&.status
  end

  shared_examples 'does not call services to create current status record' do
    it 'does not update the status' do
      expect(Issues::ReopenService).not_to receive(:new)
      expect(Issues::CloseService).not_to receive(:new)
      expect(::WorkItems::Widgets::Statuses::UpdateService).not_to receive(:new)

      run_callback
    end
  end

  shared_examples 'handle status for open state' do
    context "when work items state is open" do
      it "calls the status update service with a status with open state" do
        expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
          .with(item, current_user, status)
          .and_return(status_update_service)
        expect(status_update_service).to receive(:execute)
        expect(status.state).to eq(:open)

        run_callback
      end
    end

    context "when work items state is closed" do
      before do
        item.close(current_user)
      end

      it "calls the reopen with a status with open state" do
        expect(Issues::ReopenService).to receive_message_chain(:new, :execute).with(item, status: status)
        expect(status.state).to eq(:open)

        run_callback
      end
    end
  end

  shared_examples 'handle status for closed state' do
    context "when work items state is closed" do
      before do
        item.close(current_user)
      end

      it "calls the status update service with a status with closed state" do
        expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
          .with(item, current_user, status)
          .and_return(status_update_service)
        expect(status_update_service).to receive(:execute)
        expect(status.state).to eq(:closed)

        run_callback
      end
    end

    context "when work items state is open" do
      it "calls the close with an status with closed state" do
        expect(Issues::CloseService).to receive_message_chain(:new, :execute).with(item, status: status)
        expect(status.state).to eq(:closed)

        run_callback
      end
    end
  end

  describe '.execute_without_params?' do
    it 'returns true' do
      expect(described_class.execute_without_params?).to be true
    end
  end

  describe '#after_create' do
    subject(:run_callback) { callback.after_create }

    context 'when feature is not available' do
      let(:params) { { status: done_status } }

      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    shared_examples 'sets the default status' do
      it 'calls the status update service with the default status' do
        expect(::WorkItems::Widgets::Statuses::UpdateService).to receive(:new)
          .with(item, current_user, :default)
          .and_return(status_update_service)
        expect(status_update_service).to receive(:execute)

        run_callback
      end
    end

    context 'for system defined lifecycle' do
      context 'when status param is not given' do
        it_behaves_like 'sets the default status'
      end

      context 'when status param is given' do
        let(:params) { { status: in_progress_status } }

        it_behaves_like 'handle status for open state' do
          let(:status) { in_progress_status }
        end
      end

      context 'when status name param is given' do
        let(:params) { { name: in_progress_status.name } }

        it_behaves_like 'handle status for open state' do
          let(:status) { in_progress_status }
        end
      end

      context 'when status name does not match a status on the lifecycle' do
        let(:params) { { name: 'Not a real status' } }

        it 'raises an error listing the valid status names' do
          expect { run_callback }
            .to raise_error(
              ::Issuable::Callbacks::Base::Error,
              /Status 'Not a real status' is not valid for this work item type. Valid statuses are: /
            )
        end
      end

      context 'when user does not have permission to set status' do
        let(:current_user) { create(:user) }

        it_behaves_like 'sets the default status'
      end
    end

    context 'for custom lifecycle' do
      let!(:status_lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
          create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item.work_item_type)
        end
      end

      context 'when status param is not given' do
        it_behaves_like 'sets the default status'
      end

      context 'when status param is given' do
        let(:params) { { status: status_lifecycle.default_closed_status } }

        it_behaves_like 'handle status for closed state' do
          let(:status) { status_lifecycle.default_closed_status }
        end
      end

      context 'when status is invalid' do
        let(:status_from_other_group) { create(:work_item_custom_status) }
        let(:params) { { status: status_from_other_group } }

        it_behaves_like 'sets the default status'
      end
    end
  end

  describe '#after_update' do
    subject(:run_callback) { callback.after_update }

    context 'when feature is not available' do
      let(:params) { { status: done_status } }

      before do
        stub_licensed_features(work_item_status: false)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    context 'when user does not have permission' do
      let(:params) { { status: done_status } }

      before do
        allow(callback).to receive(:has_permission?).and_return(false)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    context 'when work item is excluded in new type' do
      before do
        allow(callback).to receive(:excluded_in_new_type?).and_return(true)
      end

      it_behaves_like 'does not call services to create current status record'
    end

    context "when params are empty" do
      it_behaves_like 'does not call services to create current status record'
    end

    context 'when work item type does not support statuses' do
      let(:item) { unsupported_work_item }
      let(:params) { { status: done_status } }

      it_behaves_like 'does not call services to create current status record'
    end

    context "for system defined lifecycle" do
      context "when status category has open state" do
        let(:params) { { status: in_progress_status } }

        it_behaves_like 'handle status for open state' do
          let(:status) { in_progress_status }
        end
      end

      context "when status category has closed state" do
        let(:params) { { status: done_status } }

        it_behaves_like 'handle status for closed state' do
          let(:status) { done_status }
        end
      end

      context "when status name param is given" do
        let(:params) { { name: in_progress_status.name } }

        it_behaves_like 'handle status for open state' do
          let(:status) { in_progress_status }
        end
      end

      context "when status name param is given case-insensitively with surrounding whitespace" do
        let(:params) { { name: "  #{in_progress_status.name.upcase}  " } }

        it_behaves_like 'handle status for open state' do
          let(:status) { in_progress_status }
        end
      end

      context "when status name does not match a status on the lifecycle" do
        let(:params) { { name: 'Not a real status' } }

        it 'raises an error listing the valid status names' do
          expect { run_callback }
            .to raise_error(
              ::Issuable::Callbacks::Base::Error,
              /Status 'Not a real status' is not valid for this work item type. Valid statuses are: /
            )
        end
      end
    end

    context "for custom lifecycle" do
      let!(:status_lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
          create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item.work_item_type)
        end
      end

      let(:open_status) { status_lifecycle.default_open_status }
      let(:closed_status) { status_lifecycle.default_closed_status }

      context "when status category has open state" do
        let(:params) { { status: open_status } }

        it_behaves_like 'handle status for open state' do
          let(:status) { open_status }
        end
      end

      context "when status category has closed state" do
        let(:params) { { status: closed_status } }

        it_behaves_like 'handle status for closed state' do
          let(:status) { closed_status }
        end
      end

      context "when status name param is given" do
        let(:params) { { name: open_status.name } }

        it_behaves_like 'handle status for open state' do
          let(:status) { open_status }
        end
      end

      context "when status is invalid" do
        let(:status_from_other_group) { create(:work_item_custom_status) }
        let(:params) { { status: status_from_other_group } }

        it_behaves_like 'does not call services to create current status record'
      end
    end
  end

  describe '#after_update_commit' do
    let_it_be_with_reload(:item) { create(:work_item, :issue, project: project) }

    before_all do
      project.add_developer(current_user)
      described_class.new(issuable: item, current_user: current_user, params: {}).after_create
    end

    shared_examples 'publishes a StatusChangedEvent' do
      it 'publishes' do
        callback = described_class.new(issuable: work_item, current_user: current_user, params: status_params)
        callback.after_update

        expect { callback.after_update_commit }
          .to publish_event(::WorkItems::StatusChangedEvent)
      end
    end

    shared_examples 'does not publish a StatusChangedEvent' do
      it 'does not publish' do
        callback = described_class.new(issuable: work_item, current_user: current_user, params: status_params)
        callback.after_update

        expect { callback.after_update_commit }
          .not_to publish_event(::WorkItems::StatusChangedEvent)
      end
    end

    context 'when changing to a new status' do
      let(:work_item) { item }
      let(:status_params) { { status: in_progress_status } }

      it_behaves_like 'publishes a StatusChangedEvent'
    end

    context 'when custom lifecycle status_id changes' do
      let_it_be_with_reload(:custom_item) { create(:work_item, :task, project: project) }

      let!(:status_lifecycle) do
        create(:work_item_custom_lifecycle, namespace: group).tap do |lifecycle|
          create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: custom_item.work_item_type)
        end
      end

      let(:work_item) { custom_item }
      let(:status_params) { { status: status_lifecycle.default_closed_status } }

      before do
        described_class.new(issuable: custom_item, current_user: current_user, params: {}).after_create
        custom_item.reload
      end

      it_behaves_like 'publishes a StatusChangedEvent'
    end

    context 'when changing to a different status after a previous change' do
      let(:work_item) { item }
      let(:status_params) { { status: done_status } }

      before do
        first_change = described_class.new(issuable: item, current_user: current_user,
          params: { status: in_progress_status })
        first_change.after_update
        first_change.after_update_commit
        item.reload
      end

      it_behaves_like 'publishes a StatusChangedEvent'
    end

    context 'when status is set to the same value' do
      let(:work_item) { item }
      let(:status_params) { { status: in_progress_status } }

      before do
        initial_change = described_class.new(issuable: item, current_user: current_user, params: status_params)
        initial_change.after_update
        initial_change.after_update_commit
        item.reload
      end

      it_behaves_like 'does not publish a StatusChangedEvent'
    end

    context 'when the work item has no project' do
      let_it_be_with_reload(:group_item) { create(:work_item, :group_level, namespace: group) }

      let(:work_item) { group_item }
      let(:status_params) { { status: in_progress_status } }

      before do
        described_class.new(issuable: group_item, current_user: current_user, params: {}).after_create
      end

      it_behaves_like 'does not publish a StatusChangedEvent'
    end

    context 'when no status change occurs' do
      let(:work_item) { item.reload }
      let(:status_params) { {} }

      it_behaves_like 'does not publish a StatusChangedEvent'
    end
  end
end
