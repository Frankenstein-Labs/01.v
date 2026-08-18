# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ActiveUserCountThresholdWorker, feature_category: :plan_provisioning do
  using RSpec::Parameterized::TableSyntax

  subject(:worker) { described_class.new }

  let(:license) { build(:license) }

  describe '#perform' do
    where(:trial?, :threshold_reached?, :remaining_user_count, :should_send_reminder?) do
      false | false | 1  | false
      false | true  | 1  | true
      false | true  | 0  | false
      false | true  | -1 | false
      true  | false | 1  | false
      true  | true  | 1  | false
    end

    with_them do
      before do
        allow(license).to receive(:trial?).and_return(trial?)
        allow(license).to receive(:active_user_count_threshold_reached?).and_return(threshold_reached?)
        allow(license).to receive(:remaining_user_count).and_return(remaining_user_count)
        allow(License).to receive(:current).and_return(license)
      end

      it do
        if should_send_reminder?
          expect { worker.perform }.to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
        else
          expect { worker.perform }.not_to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
        end
      end
    end

    context 'with recipients' do
      # `freeze: false` is required here: this `let_it_be` subject is mutated
      # in-memory across examples in a way that survives both
      # `let_it_be_with_reload` and `let_it_be_with_refind` (e.g. a memoized
      # association/collection or a non-persisted attribute). Keeping it unfrozen
      # is the only correct cure (see gitlab-org/gitlab#602925).
      let_it_be(:admins, freeze: false) { create_list(:admin, 3) }

      before do
        allow(license).to receive(:trial?).and_return(false)
        allow(license).to receive(:active_user_count_threshold_reached?).and_return(true)
        allow(license).to receive(:remaining_user_count).and_return(1)
        allow(License).to receive(:current).and_return(license)
      end

      it 'sends reminder to admins only' do
        admins_emails = admins.pluck(:email)

        expect { worker.perform }.to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
          .with(array_including(*admins_emails))
      end

      it 'adds a licensee email to the recipients list' do
        allow(license).to receive(:licensee).and_return({ 'Email' => admins.first.email })
        licensee_email = license.licensee['Email']

        expect { worker.perform }.to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
          .with(array_including(licensee_email))
      end

      it 'sends reminder to unique emails' do
        admins_emails = admins.pluck(:email)
        allow(license.licensee).to receive('Email').and_return(admins.first.email)

        expect { worker.perform }.to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
          .with(array_including(*admins_emails))
      end

      it 'sends reminder to active admins only' do
        admins.first.deactivate!

        active_admins_emails = admins.drop(1).pluck(:email)

        expect { worker.perform }.to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
          .with(array_including(*active_admins_emails))
      end
    end

    context 'when there is no license' do
      it 'does not send a reminder' do
        expect { worker.perform }.not_to have_enqueued_mail(LicenseMailer, :approaching_active_user_count_limit)
      end
    end
  end
end
