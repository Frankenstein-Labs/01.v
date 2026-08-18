# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Weight, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project, author: user, weight: 1) }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  describe '#after_initialize' do
    subject(:after_initialize_callback) { callback.after_initialize }

    shared_examples 'weight is unchanged' do
      it 'does not change work item weight value' do
        expect { after_initialize_callback }
          .to not_change { work_item.weight }
      end
    end

    context 'when weight feature is licensed' do
      before do
        stub_licensed_features(issue_weights: true)
      end

      context 'when user can only update work item' do
        let(:params) { { weight: 2 } }

        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'weight is unchanged'
      end

      context 'when user can admin work item' do
        before_all do
          project.add_reporter(user)
        end

        context 'when weight param is present' do
          where(:new_weight) do
            [[2], [nil]]
          end

          with_them do
            let(:params) { { weight: new_weight } }

            it 'correctly sets work item weight value' do
              after_initialize_callback

              expect(work_item.weight).to eq(new_weight)
            end
          end
        end

        context 'when weight param is not present' do
          let(:params) { {} }

          it_behaves_like 'weight is unchanged'
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
          end

          it "removes the work item's weight" do
            after_initialize_callback

            expect(work_item.weight).to be_nil
          end
        end
      end
    end
  end
end
