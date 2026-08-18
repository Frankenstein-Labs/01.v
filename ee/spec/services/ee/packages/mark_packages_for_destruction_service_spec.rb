# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::MarkPackagesForDestructionService, :aggregate_failures, feature_category: :package_registry do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:packages) { create_list(:nuget_package, 2, project: project) }

  let(:user) { project.owner }

  let(:service) { described_class.new(packages: ::Packages::Package.id_in(packages.map(&:id)), current_user: user) }

  describe '#send_audit_events' do
    it 'calls CreateAuditEventsService' do
      expect_next_instance_of(
        ::Packages::CreateAuditEventsService,
        packages,
        current_user: user
      ) do |service|
        expect(service).to receive(:execute)
      end

      service.execute
    end
  end
end
