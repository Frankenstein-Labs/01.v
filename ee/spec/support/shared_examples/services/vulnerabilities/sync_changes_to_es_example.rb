# frozen_string_literal: true

#
# Shared context + shared examples for ES vulnerability sync specs.
#
# NOTE: For retro-compatibility, we keep *two* positive shared examples:
#
#   1. `sync vulnerabilities changes to ES` (original style)
#      - uses a `let(:expected_vulnerabilities)` defined in the spec
#      - compares captured `received_vulnerabilities` against it
#
#   2. `it syncs vulnerabilities with ES` (newer explicit-IDs style)
#      - takes a proc returning vulnerability IDs
#      - asserts `track!` was called with objects matching those IDs
#
# Both include `with ES stubs` to share the same setup.
#
# TODO: Migrate all specs to `it syncs vulnerabilities with ES`
# and remove `sync vulnerabilities changes to ES` once no longer used.
# Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/572489
#

RSpec.shared_context 'with ES stubs' do
  let(:received_vulnerabilities) { [] }

  before do
    allow(::Search::Elastic::VulnerabilityIndexHelper)
      .to receive(:indexing_allowed?).and_return(true)

    allow(::Elastic::ProcessBookkeepingService).to receive(:track!) do |*vulnerabilities|
      received_vulnerabilities.concat(vulnerabilities)
    end

    # rubocop:disable RSpec/AnyInstanceOf -- Needed to stub instance method globally in ES sync tests
    allow_any_instance_of(::Vulnerability)
      .to receive(:maintaining_elasticsearch?).and_return(true)
    allow_any_instance_of(::Vulnerabilities::Read)
      .to receive(:maintaining_elasticsearch?).and_return(true)
    # rubocop:enable RSpec/AnyInstanceOf
  end
end

RSpec.shared_examples 'sync vulnerabilities changes to ES' do
  include_context 'with ES stubs'

  it 'calls the ProcessBookkeepingService with vulnerabilities' do
    subject

    expect(::Elastic::ProcessBookkeepingService).to have_received(:track!).at_least(:once)
    expect(received_vulnerabilities.uniq).to match_array(Array(expected_vulnerabilities))
  end
end

RSpec.shared_examples 'it syncs vulnerabilities with ES' do |expected_vulnerabilities_proc, subject_name = :subject|
  include_context 'with ES stubs'

  it 'triggers ES sync' do
    public_send(subject_name)

    expected_vulnerabilities = instance_exec(&expected_vulnerabilities_proc)

    expect(::Elastic::ProcessBookkeepingService)
      .to have_received(:track!)
      .with(*expected_vulnerabilities.map { |id| an_object_having_attributes(id: id) })
  end
end

RSpec.shared_examples 'does not sync with ES when no vulnerabilities' do |subject_name = :subject|
  include_context 'with ES stubs'

  it 'does not sync vulnerabilities with ES' do
    public_send(subject_name)

    vulnerability_syncs = received_vulnerabilities.select do |record|
      record.is_a?(::Vulnerability) || record.is_a?(::Vulnerabilities::Read)
    end

    expect(vulnerability_syncs).to be_empty
  end
end
