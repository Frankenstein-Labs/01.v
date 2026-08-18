# frozen_string_literal: true

RSpec.shared_examples 'page quick action' do
  describe '/page' do
    context 'when licensed features are disabled' do
      before do
        visit project_issue_path(project, incident)
        wait_for_all_requests
      end

      it 'does not escalate incident' do
        add_note('/page spec policy')

        expect(page).to have_content('Could not apply page command')
      end
    end

    context 'when licensed features are enabled' do
      before do
        stub_licensed_features(oncall_schedules: true, escalation_policies: true)
        visit project_issue_path(project, incident)
        wait_for_all_requests
      end

      it 'starts escalation with the policy' do
        add_note('/page spec policy')

        expect(page).to have_content('Started escalation for this incident.')
        expect(incident.reload.escalation_status.policy).to eq(escalation_policy)
      end

      it 'starts escalation with policy name as case insensitive' do
        add_note('/page SpEc Policy')

        expect(page).to have_content('Started escalation for this incident.')
        expect(incident.reload.escalation_status.policy).to eq(escalation_policy)
      end

      it 'does not escalate when policy does not exist' do
        add_note('/page wrong policy')

        expect(page).to have_content("Policy 'wrong policy' does not exist.")
        expect(incident.reload.escalation_status.policy).to be_nil
      end

      context 'when incident is already escalated' do
        before do
          # Escalate a policy before paging again
          add_note('/page spec policy')
        end

        it 'does not escalate again with same policy' do
          add_note('/page spec policy')

          expect(page).to have_content("This incident is already escalated with 'spec policy'.")
        end
      end

      context 'when incident already has an alert' do
        let_it_be(:alert, freeze: false) { create(:alert_management_alert, issue: incident) }

        it 'starts escalation with the policy' do
          add_note('/page spec policy')

          expect(page).to have_content('Started escalation for this incident.')
          expect(incident.reload.escalation_status.policy).to eq(escalation_policy)
        end
      end
    end
  end
end
