# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::GeoNodeStatusCheck, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:current_node, freeze: true) { create(:geo_node) }

  let(:geo_node_status) do
    build(:geo_node_status, :replicated_and_verified, geo_node: current_node)
  end

  subject(:geo_node_status_check) { described_class.new(geo_node_status, current_node) }

  describe '#replication_verification_complete?' do
    before do
      # We disable the transaction_open? check because Gitlab::Database::BatchCounter.batch_count
      # is not allowed within a transaction but all RSpec tests run inside of a transaction.
      stub_batch_counter_transaction_open_check
      allow(Gitlab.config.geo.registry_replication).to receive(:enabled).and_return(true)
    end

    context 'with replicators' do
      context 'with replication checks' do
        let(:replicators) { Gitlab::Geo.replication_enabled_replicator_classes }
        let(:checks) do
          replicators.map { |k| /#{k.replicable_title_plural} replicated:/ }
        end

        it 'prints messages for replication' do
          checks.each do |text|
            expect { geo_node_status_check.print_replication_verification_status }.to output(text).to_stdout
          end
        end
      end

      context 'with verification checks' do
        let(:replicators) { Gitlab::Geo.verification_enabled_replicator_classes }
        let(:checks) do
          replicators.map { |k| /#{k.replicable_title_plural} verified:/ }
        end

        context 'when verification is enabled' do
          it 'prints messages for verification checks' do
            checks.each do |text|
              expect { geo_node_status_check.print_replication_verification_status }.to output(text).to_stdout
            end
          end
        end

        context 'when verification is disabled' do
          it 'does not print messages for verification checks' do
            replicators.each do |replicator|
              allow(replicator).to receive(:verification_enabled?).and_return(false)
            end

            checks.each do |text|
              expect { geo_node_status_check.print_replication_verification_status }.not_to output(text).to_stdout
            end
          end
        end
      end
    end

    context 'when replication is up-to-date' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:repository_checks_enabled).and_return(true)
      end

      it 'returns true when all replicables have data to sync' do
        expect(geo_node_status_check.replication_verification_complete?).to be_truthy
      end

      it 'returns true when some replicables does not have data to sync' do
        geo_node_status.update!(
          repositories_count: 0
        )

        expect(geo_node_status_check.replication_verification_complete?).to be_truthy
      end
    end

    context 'when replication is not up-to-date' do
      it 'returns false when not all replicables were synced' do
        geo_node_status.update!(repositories_count: 5)

        expect(geo_node_status_check.replication_verification_complete?).to be_falsy
      end
    end
  end

  describe '#print_geo_role (isolated role output)' do
    context 'when node is primary' do
      let_it_be(:primary_node, freeze: true) { create(:geo_node, :primary) }

      before do
        stub_current_geo_node(primary_node)
      end

      it 'prints Primary' do
        expect { geo_node_status_check.send(:print_geo_role) }.to output(/Primary/).to_stdout
      end
    end

    context 'when node is secondary' do
      before do
        stub_current_geo_node(current_node)
      end

      it 'prints Secondary' do
        expect { geo_node_status_check.send(:print_geo_role) }.to output(/Secondary/).to_stdout
      end
    end

    context 'when node is org migration target' do
      before do
        stub_org_migration_target_cell(current_node)
      end

      it 'prints Org Migration Target Cell' do
        expect { geo_node_status_check.send(:print_geo_role) }.to output(/Org Migration Target Cell/).to_stdout
      end
    end

    context 'when node role is unknown' do
      before do
        allow(Gitlab::Geo).to receive_messages(primary?: false, org_migration_target?: false, secondary?: false)
      end

      it 'prints unknown' do
        expect { geo_node_status_check.send(:print_geo_role) }.to output(/unknown/).to_stdout
      end
    end
  end
end
