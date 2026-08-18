# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::UserSettingChangesAuditor, feature_category: :user_profile do
  using RSpec::Parameterized::TableSyntax
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user) }

    subject(:user_setting_changes_auditor) { described_class.new(user) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    context 'when user setting is updated' do
      where(:column, :changes, :events) do
        'private_profile' | [{ change: 'user_profile_visiblity', event_type: 'user_profile_visiblity_updated' },
          { change: 'user_profile_visibility', event_type: 'user_profile_visibility_updated' }] |
          [true, false]
      end

      with_them do
        before do
          user.update!(column.to_sym => events.first)
        end

        it 'calls auditor for both the legacy misspelled event and the new correctly spelled event' do
          user.update!(column.to_sym => events.last)

          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            {
              name: changes.first[:event_type],
              author: user,
              scope: user,
              target: user,
              message: "Changed #{changes.first[:change]} from #{events.first} to #{events.last}",
              additional_details: {
                change: changes.first[:change].to_s,
                from: events.first,
                to: events.last
              },
              target_details: nil
            }
          ).ordered.and_call_original

          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            {
              name: changes.last[:event_type],
              author: user,
              scope: user,
              target: user,
              message: "Changed #{changes.last[:change]} from #{events.first} to #{events.last}",
              additional_details: {
                change: changes.last[:change].to_s,
                from: events.first,
                to: events.last
              },
              target_details: nil
            }
          ).ordered.and_call_original

          user_setting_changes_auditor.execute
        end
      end
    end
  end
end
