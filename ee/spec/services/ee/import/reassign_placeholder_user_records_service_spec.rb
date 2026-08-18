# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::ReassignPlaceholderUserRecordsService, feature_category: :importers do
  include_context 'with reassign placeholder user records'

  let_it_be(:service_account) { create(:service_account, provisioned_by_group: namespace) }

  describe '#execute', :aggregate_failures do
    context 'when reassign to user is a service account bot' do
      before do
        source_user.update!(reassign_to_user: service_account)
      end

      it_behaves_like 'a successful reassignment'

      it_behaves_like 'reassigns placeholder user records' do
        let(:reassign_user_id) { service_account.id }
      end

      it_behaves_like 'handles membership creation for reassigned users' do
        let(:reassign_user) { service_account }
      end
    end
  end
end
