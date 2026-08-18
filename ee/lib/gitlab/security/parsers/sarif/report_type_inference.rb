# frozen_string_literal: true

module Gitlab
  module Security
    module Parsers
      class Sarif
        module ReportTypeInference
          SECRET_CWES = %w[798 259 321 522 312 319 256 257 540].to_set.freeze

          class << self
            def infer(result:, rule:)
              semantic_ids = IdentifierExtractor.semantic_identifiers(result: result, rule: rule)
              infer_from(semantic_ids: semantic_ids)
            end

            def infer_from(semantic_ids:)
              if any_cve?(semantic_ids)
                :dependency_scanning
              elsif any_secret_cwe?(semantic_ids)
                :secret_detection
              else
                :sast
              end
            end

            private

            def any_cve?(ids)
              ids.any? { |id| id[:type] == :cve }
            end

            def any_secret_cwe?(ids)
              ids.any? { |id| id[:type] == :cwe && SECRET_CWES.include?(id[:number]) }
            end
          end
        end
      end
    end
  end
end
