# frozen_string_literal: true

require 'spec_helper'

module FileHelper
  def stub_file(content)
    file = Tempfile.new
    file.write(content)
    file.rewind
    allow(file).to receive(:open).and_yield(file)
    file
  end
end
