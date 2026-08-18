# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ReferenceExtractor do
  let_it_be(:group)   { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  before_all do
    group.add_developer(project.creator)
  end

  subject { described_class.new(project, project.creator) }

  describe 'referables prefixes' do
    def prefixes
      described_class.referrables.each_with_object({}) do |referable, result|
        class_name = referable.to_s.camelize
        klass = class_name.constantize if Object.const_defined?(class_name)
        klass = ::Iterations::Cadence if referable == :iterations_cadence

        next unless klass.respond_to?(:reference_prefix)

        prefix = klass.reference_prefix
        result[prefix] ||= []
        result[prefix] << referable
      end
    end

    it 'returns all supported prefixes' do
      expect(prefixes.keys.uniq).to match_array(%w(@ # ~ % ! $ & [vulnerability: *iteration: [cadence:))
    end
  end

  it 'accesses valid epics' do
    stub_licensed_features(epics: true)

    @e0 = create(:epic, group: group)
    @e1 = create(:epic, group: group)
    @e2 = create(:epic, group: create(:group, :private))

    text = "#{@e0.to_reference(group, full: true)}, &#{non_existing_record_iid}, #{@e1.to_reference(group, full: true)}, #{@e2.to_reference(group, full: true)}"

    subject.analyze(text, { group: group })

    expect(subject.epics).to match_array([@e0, @e1])
  end

  context 'for iterations cadences', feature_category: :team_planning do
    let_it_be(:cadence1) { create(:iterations_cadence, group: group) }
    let_it_be(:cadence2) { create(:iterations_cadence, group: group) }
    let_it_be(:cadence3) { create(:iterations_cadence, group: create(:group, :private)) }

    before do
      stub_licensed_features(iterations: true)
    end

    it 'accesses valid iterations cadences' do
      inaccessible_cadence_ref = cadence3.to_reference
      accessible_cadence_refs = "#{cadence1.to_reference}, #{cadence2.to_reference}"
      text = "#{accessible_cadence_refs}, #{inaccessible_cadence_ref}, [cadence:#{non_existing_record_id}]"

      subject.analyze(text, { group: group })

      expect(subject.iterations_cadences).to match_array([cadence1, cadence2])
    end
  end

  context 'for vulnerabilities' do
    let_it_be(:vulnerability_0) { create(:vulnerability, project: project) }
    let_it_be(:vulnerability_1) { create(:vulnerability, project: project) }
    let_it_be(:vulnerability_2) { create(:vulnerability, project: create(:project, :private)) }

    let(:text) { "#{vulnerability_0.to_reference(project, full: true)}, [vulnerability:#{non_existing_record_id}], #{vulnerability_1.to_reference(project, full: true)}, #{vulnerability_2.to_reference(project, full: true)}" }

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it 'accesses valid vulnerabilities' do
      subject.analyze(text, { project: project })

      expect(subject.vulnerabilities).to match_array([vulnerability_0, vulnerability_1])
    end
  end
end
