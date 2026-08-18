# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::VerificationStatus, feature_category: :requirements_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:work_item) { create(:work_item, :requirement, project: project, author: user) }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  def work_item_verification_status
    state = work_item.reload.requirement&.last_test_report_state
    ::WorkItems::Widgets::VerificationStatus::STATUS_MAP[state]
  end

  describe '#before_update' do
    subject(:before_update_callback) { callback.before_update }

    shared_examples 'work item and verification status is unchanged' do
      it 'does not change work item verification status value' do
        expect { subject }
          .to not_change { work_item_verification_status }
          .and not_change { work_item }
      end
    end

    shared_examples 'verification status is updated' do |new_value|
      it 'updates work item verification status value' do
        expect { subject }
          .to change { work_item_verification_status }.to(new_value)
      end
    end

    context 'when verification status feature is licensed' do
      before do
        stub_licensed_features(requirements: true)
      end

      context 'when user cannot update work item' do
        let(:params) { { verification_status: "failed" } }

        before_all do
          project.add_guest(user)
        end

        it_behaves_like 'work item and verification status is unchanged'
      end

      context 'when user can update work item' do
        before_all do
          project.add_reporter(user)
        end

        context 'when verification status param is present' do
          context 'when verification status param is valid' do
            let(:params) { { verification_status: 'failed' } }

            it_behaves_like 'verification status is updated', 'failed'
          end

          context 'when verification status param is equivalent' do
            let(:params) { { verification_status: 'passed' } }

            it_behaves_like 'verification status is updated', 'satisfied'
          end

          context 'when verification status param is invalid' do
            where(:new_status) do
              %w[unverified nonsense satisfied]
            end

            with_them do
              let(:params) { { verification_status: new_status } }

              it 'errors' do
                expect { before_update_callback }.to raise_error(ArgumentError, /is not a valid state/)
              end
            end
          end
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          let_it_be(:test_report1) { create(:test_report, requirement_issue: work_item) }
          let_it_be(:test_report2) { create(:test_report, requirement_issue: work_item) }
          let_it_be(:other_test_report) do
            create(:test_report, requirement_issue: create(:work_item, :requirement, project: project))
          end

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
          end

          it "deletes the associated test report and requirement" do
            requirement = work_item.requirement

            expect { before_update_callback }.to change { work_item.test_reports.count }.from(2).to(0)

            expect(RequirementsManagement::TestReport.exists?(test_report1.id)).to be false
            expect(RequirementsManagement::TestReport.exists?(test_report2.id)).to be false
            expect(RequirementsManagement::Requirement.exists?(requirement.id)).to be false
            expect(RequirementsManagement::TestReport.exists?(other_test_report.id)).to be true
          end
        end

        context 'when verification status param is not present' do
          let(:params) { {} }

          it_behaves_like 'work item and verification status is unchanged'
        end

        context 'when verification status param is nil' do
          let(:params) { { verification_status: nil } }

          it_behaves_like 'work item and verification status is unchanged'
        end
      end
    end
  end
end
