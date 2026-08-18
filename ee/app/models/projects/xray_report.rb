# frozen_string_literal: true

module Projects
  class XrayReport < ApplicationRecord
    include Gitlab::Utils::StrongMemoize

    belongs_to :project

    validates :project, :payload, :lang, presence: true
    validates :lang, uniqueness: { scope: :project }
    validates :payload, json_schema: { filename: 'xray_report' }

    scope :for_lang, ->(lang) { where(lang: lang) }
    scope :for_project, ->(project) { where(project: project) }

    # instance methods below works with XRay report payload that
    # is being sourced from LLM model. Since LLM models can
    # hallucinate additional precaution needs to be taken to make
    # sure that malformed report will not break code generation flow
    def libs
      payload['libs'] || []
    end
  end
end
