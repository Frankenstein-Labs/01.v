# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Packages::Downloadable, feature_category: :package_registry do
  context 'with a package' do
    let_it_be_with_reload(:package) { create(:generic_package) }

    shared_examples 'updating the last_downloaded_at column' do
      before do
        allow(::Gitlab::Geo).to receive(:secondary?).and_return(secondary)
      end

      context 'when not on a geo secondary' do
        let(:secondary) { false }

        it 'updates the last_downloaded_at column' do
          expect { execute }.to change { package.reload.last_downloaded_at }
        end
      end

      context 'when on a geo secondary' do
        let(:secondary) { true }

        it 'does not update the last_downloaded_at column' do
          expect { execute }.not_to change { package.reload.last_downloaded_at }
        end
      end
    end

    describe '#touch_last_downloaded_at' do
      subject(:execute) { package.touch_last_downloaded_at }

      it_behaves_like 'updating the last_downloaded_at column'
    end

    describe '.touch_last_downloaded_at' do
      subject(:execute) { ::Packages::Generic::Package.touch_last_downloaded_at(package.id) }

      it_behaves_like 'updating the last_downloaded_at column'
    end
  end
end
