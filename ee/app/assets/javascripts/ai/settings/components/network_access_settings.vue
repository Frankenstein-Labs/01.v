<script>
import { s__ } from '~/locale';

import DomainListCard from './domain_list_card.vue';
import NetworkAccessSettingsForm from './network_access_settings_form.vue';

export default {
  name: 'NetworkAccessSettings',

  components: {
    DomainListCard,
    NetworkAccessSettingsForm,
  },

  props: {
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    includeRecommendedAllowedDomains: {
      type: Boolean,
      required: true,
    },
    allowAllUnixSockets: {
      type: Boolean,
      required: true,
    },
    allowProjectExtension: {
      type: Boolean,
      required: true,
    },
    disabledCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
  },

  emits: [
    'include-recommended-allowed-domains-changed',
    'allow-all-unix-sockets-changed',
    'allow-project-extension-changed',
  ],

  i18n: {
    networkAccessHeading: s__('AiPowered|Network access'),
    allowedDomainsHeading: s__('AiPowered|Allowed domains'),
    blockedDomainsHeading: s__('AiPowered|Blocked domains'),
    allowlist: s__('AiPowered|Allowlist'),
    denylist: s__('AiPowered|Denylist'),
    noAllowlistEntries: s__('AiPowered|No allowlist entries.'),
    noDenylistEntries: s__('AiPowered|No denylist entries.'),
    failedToLoadAllowlist: s__('AiPowered|Failed to load allowlist domains.'),
    failedToLoadDenylist: s__('AiPowered|Failed to load denylist domains.'),
    denylistDescription: s__(
      'AiPowered|Domains in the denylist are always blocked, even if they appear in the allowlist.',
    ),
  },
};
</script>

<template>
  <div class="gl-my-4">
    <h3 class="gl-heading-4 gl-mb-5 gl-mt-6">{{ $options.i18n.networkAccessHeading }}</h3>

    <network-access-settings-form
      :include-recommended-allowed-domains="includeRecommendedAllowedDomains"
      :allow-all-unix-sockets="allowAllUnixSockets"
      :allow-project-extension="allowProjectExtension"
      :disabled-checkbox="disabledCheckbox"
      @include-recommended-allowed-domains-changed="
        $emit('include-recommended-allowed-domains-changed', $event)
      "
      @allow-all-unix-sockets-changed="$emit('allow-all-unix-sockets-changed', $event)"
      @allow-project-extension-changed="$emit('allow-project-extension-changed', $event)"
    />

    <h4 class="gl-heading-5 gl-mb-5">{{ $options.i18n.allowedDomainsHeading }}</h4>

    <domain-list-card
      domain-type="ALLOWED"
      :title="$options.i18n.allowlist"
      :empty-state-text="$options.i18n.noAllowlistEntries"
      :error-text="$options.i18n.failedToLoadAllowlist"
      :group-full-path="groupFullPath"
      data-testid="allowlist-card"
    />

    <h4 class="gl-heading-5 gl-mb-2 gl-mt-5">{{ $options.i18n.blockedDomainsHeading }}</h4>
    <p class="gl-text-subtle">
      {{ $options.i18n.denylistDescription }}
    </p>
    <domain-list-card
      domain-type="DENIED"
      :title="$options.i18n.denylist"
      :empty-state-text="$options.i18n.noDenylistEntries"
      :error-text="$options.i18n.failedToLoadDenylist"
      :group-full-path="groupFullPath"
      data-testid="denylist-card"
    />
  </div>
</template>
