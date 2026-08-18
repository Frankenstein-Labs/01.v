# frozen_string_literal: true

module Members
  class DestroyLdapGroupLinkService
    def self.execute(ldap_group_link)
      new(ldap_group_link).execute
    end

    def initialize(ldap_group_link)
      @ldap_group_link = ldap_group_link
    end

    # Wrapping the destroy and the orphaned-provider check (but not the
    # flag reset itself) in the same group-row lock closes a race that
    # existed when destroy and check were separate, unsynchronized steps:
    # two concurrent requests removing different links for the same
    # provider could each see the other's link as still present when
    # checking whether the provider is now orphaned, so neither would
    # trigger the ldap-flag reset. The reset is idempotent and
    # order-independent, so it's safe to run outside the lock once the
    # orphaned decision has been made atomically with the destroy.
    def execute
      orphaned = false

      group.with_lock do
        ldap_group_link.destroy

        orphaned = group.ldap_group_links.with_provider(provider).none?
      end

      ::Members::ResetOrphanedLdapProviderFlagsService.execute(group, [provider]) if orphaned
    end

    private

    attr_reader :ldap_group_link

    def group
      ldap_group_link.group
    end

    def provider
      ldap_group_link.provider
    end
  end
end
