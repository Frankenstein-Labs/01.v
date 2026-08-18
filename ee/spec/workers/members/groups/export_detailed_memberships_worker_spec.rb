# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::Groups::ExportDetailedMembershipsWorker, feature_category: :system_access do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:service) { instance_double(Namespaces::Export::DetailedDataService) }

  before_all do
    group.add_owner(user)
  end

  before do
    stub_licensed_features(export_user_permissions: true)
  end

  subject(:worker) { described_class.new }

  it 'calls the service and enqueues an email' do
    expect(Namespaces::Export::DetailedDataService).to receive(:new).and_return(service)
    expect(service).to receive(:execute).and_return(ServiceResponse.success)
    expect(Notify).to receive(:memberships_export_email).once.and_call_original

    worker.perform(group.id, user.id)
  end
end
