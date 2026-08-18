# frozen_string_literal: true

module Groups
  class SshCertificate < ApplicationRecord
    include ShaAttribute

    sha256_attribute :fingerprint

    self.table_name = :group_ssh_certificates

    belongs_to :group, foreign_key: :namespace_id, inverse_of: :ssh_certificates

    scope :for_fingerprint, ->(fingerprint) { where(fingerprint: fingerprint) }
    scope :for_namespace, ->(namespace_id) { where(namespace_id: namespace_id) }

    validates :group, presence: true
    validates :title, presence: true, length: { maximum: 255 }

    validates :key,
      presence: true,
      ssh_key: true,
      length: { maximum: 5000 },
      format: { with: /\A(#{Gitlab::SSHPublicKey.supported_algorithms.join('|')})/ }

    validates :fingerprint,
      presence: true,
      uniqueness: { scope: :namespace_id,
                    message: ->(_, _) {
                      _('must be unique. This CA has already been configured for this namespace.')
                    } }
  end
end
