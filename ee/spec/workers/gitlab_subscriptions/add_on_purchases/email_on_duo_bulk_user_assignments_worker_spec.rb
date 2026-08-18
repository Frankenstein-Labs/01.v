# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::EmailOnDuoBulkUserAssignmentsWorker,
  feature_category: :seat_cost_management do
  let(:users) { create_list(:user, 3) }
  let(:user_ids) { users.map(&:id) }
  let(:email_variant) { :duo_pro_email }

  describe '#perform' do
    subject(:worker) { described_class.new.perform(user_ids, email_variant) }

    it 'schedules the correct emails for delivery' do
      expect do
        worker
      end.to have_enqueued_mail(GitlabSubscriptions::DuoSeatAssignmentMailer, email_variant).exactly(3).times
    end
  end
end
