# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../../db/seeds/data_seeder/bulk_data'

# rubocop:disable RSpec/FeatureCategory -- This was created in the context of a working group: https://handbook.gitlab.com/handbook/company/working-groups/demo-test-data/
# The better group to own this would be Engineering Productivity, but that group
# does not currently support any feature categories.
RSpec.describe DataSeeder, feature_category: :not_owned, quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/549938' do
  it 'does not create records from the excluded factories', :aggregate_failures do
    # Creating them all takes time and this spec only cares about excluding some factories from the process,
    # so not calling original here
    allow(FactoryBot).to receive(:create)

    described_class::EXCLUDED_FACTORIES.map(&:to_sym).each do |factory_name|
      expect(FactoryBot).not_to receive(:create).with(factory_name)
    end

    described_class.new(true).seed
  end
end

RSpec.describe DataSeeder, '#reuse_existing_organization', feature_category: :not_owned do
  subject(:seeder) { described_class.new(true) }

  let_it_be(:organization) { create(:organization) }

  # These specs call `reuse_existing_organization` directly rather than going through `seed`.
  # `DataSeeder` is reopened by every seed file - trials_seed.rb, mr_seed.rb, beautiful_data.rb and
  # bulk_data.rb each define their own `seed` - so whichever loads last wins. In a shared RSpec
  # process `seed` is therefore not a dependable entry point, and driving these specs through it
  # made them fail intermittently.
  def reuse_organization
    seeder.send(:reuse_existing_organization)
  end

  context 'when running on a self-managed instance outside dev/test' do
    before do
      allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
      allow(Organizations::Organization).to receive(:first).and_return(organization)
    end

    # `FactoryBot.modify` is never allowed to run for real: it mutates the global factory registry,
    # which cannot be reliably restored inside a shared RSpec process. The redefinition is therefore
    # asserted indirectly - that it is requested, and that the organization resolved for it is the
    # existing one.
    it 'redefines the common_organization factory' do
      expect(FactoryBot).to receive(:modify)

      reuse_organization
    end

    context 'when not quiet' do
      subject(:seeder) { described_class.new }

      it 'resolves the existing organization' do
        allow(FactoryBot).to receive(:modify)

        expect { reuse_organization }
          .to output(/Reusing existing organization ##{organization.id} \(#{organization.path}\)/)
          .to_stdout
      end
    end

    context 'when the instance has no organization' do
      before do
        allow(Organizations::Organization).to receive(:first).and_return(nil)
      end

      it 'does nothing' do
        expect(FactoryBot).not_to receive(:modify)

        reuse_organization
      end
    end

    context 'when the common_organization factory is not registered' do
      before do
        allow(FactoryBot.factories).to receive(:registered?).with(:common_organization).and_return(false)
      end

      it 'does nothing' do
        expect(FactoryBot).not_to receive(:modify)

        reuse_organization
      end
    end
  end

  # The validation being worked around is skipped in dev/test, so this must be too. This spec is the
  # guard rail that keeps the global factory registry intact under RSpec.
  context 'when running in dev or test' do
    before do
      allow(Gitlab).to receive(:dev_or_test_env?).and_return(true)
    end

    it 'does not touch the factory registry' do
      expect(FactoryBot).not_to receive(:modify)

      reuse_organization
    end
  end
end
# rubocop:enable RSpec/FeatureCategory
