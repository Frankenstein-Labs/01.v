# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::MergeRequestDescriptionHelper, feature_category: :dependency_management do
  describe '#code_span' do
    it 'wraps plain text in a single-backtick code span' do
      expect(helper.code_span('My title 1')).to eq('`My title 1`')
    end

    it 'widens the fence so embedded backticks cannot break out' do
      expect(helper.code_span('a`b``c')).to eq('```a`b``c```')
    end

    it 'pads with a space when the value starts or ends with a backtick' do
      expect(helper.code_span('`x`')).to eq('`` `x` ``')
    end

    it 'collapses whitespace so a newline cannot break out of the span' do
      expect(helper.code_span("x\n\n## Injected Heading")).to eq('`x ## Injected Heading`')
    end

    it 'caps over-long backtick runs so the fence stays well below the renderer limit' do
      out = helper.code_span("x#{'`' * 100}y")

      expect(out.scan(/`+/).map(&:length).max).to be <= described_class::MAX_BACKTICK_RUN + 1
    end
  end
end
