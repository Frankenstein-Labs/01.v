# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::HealthStatus, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:group) { create(:group, reporters: reporter) }
  let_it_be_with_reload(:work_item) do
    create(:work_item, :epic, namespace: group, author: user, health_status: :on_track)
  end

  let(:current_user) { reporter }
  let(:params) { {} }
  let(:callback) { described_class.new(issuable: work_item, current_user: current_user, params: params) }

  describe '#after_initialize' do
    subject(:after_initialize_callback) { callback.after_initialize }

    shared_examples 'work item and health status is unchanged' do
      it 'does not change work item health status value' do
        expect { after_initialize_callback }
          .to not_change { work_item.health_status }
                .and not_change { work_item.updated_at }
      end
    end

    context 'when issuable_health_status feature is licensed' do
      before do
        stub_licensed_features(epics: true, issuable_health_status: true)
      end

      context 'when health_status param is present' do
        context 'when health_status param is valid' do
          let(:params) { { health_status: :needs_attention } }

          it 'updates work item health status value' do
            expect { after_initialize_callback }.to change { work_item.health_status }.to('needs_attention')
          end

          context 'without group level work items license' do
            before do
              stub_licensed_features(epics: false, issuable_health_status: true)
            end

            it_behaves_like 'work item and health status is unchanged'
          end
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
          end

          it "sets the work item's health status as nil" do
            expect { callback.after_initialize }.to change { work_item.health_status }.from('on_track').to(nil)
          end
        end
      end

      context 'when health_status param is not present' do
        let(:params) { {} }

        it_behaves_like 'work item and health status is unchanged'
      end

      context 'when param value is the same as the work item health status' do
        let(:params) { { health_status: :on_track } }

        it_behaves_like 'work item and health status is unchanged'
      end

      context 'when user cannot admin_work_item' do
        let(:current_user) { user }
        let(:params) { { health_status: :needs_attention } }

        it_behaves_like 'work item and health status is unchanged'
      end
    end

    context 'when issuable_health_status feature is unlicensed' do
      before do
        stub_licensed_features(epics: true, issuable_health_status: false)
      end

      it_behaves_like 'work item and health status is unchanged'
    end
  end
end
