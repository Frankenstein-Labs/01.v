<script>
import { GlSprintf, GlBadge, GlCard, GlPopover, GlButton } from '@gitlab/ui';
import { VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'GeoReplicableItemVerificationInfo',
  components: {
    GlSprintf,
    GlBadge,
    GlCard,
    GlButton,
    GlPopover,
    TimeAgo,
    ClipboardButton,
    HelpIcon,
    HelpPageLink,
  },
  props: {
    replicableItem: {
      type: Object,
      required: true,
    },
  },
  emits: ['reverify'],
  i18n: {
    copy: __('Copy'),
    verificationInformation: s__('Geo|Verification information'),
    verificationHelpText: s__(
      'Geo|Shows the current verification status between the Primary and Secondary Geo site for this registry and whether it has encountered any issues during the verification process.',
    ),
    learnMore: __('Learn more'),
    reverify: s__('Geo|Reverify'),
    verificationChecksum: s__('Geo|Checksum: %{verificationChecksum}'),
    expectedVerificationChecksum: s__('Geo|Expected checksum: %{verificationChecksum}'),
    lastVerifiedAt: s__('Geo|Last verified: %{timeAgo}'),
    verificationStartedAt: s__('Geo|Verification started: %{timeAgo}'),
    statusBadge: s__('Geo|Status: %{badge}'),
    verificationRetryAt: s__(
      'Geo|%{noBoldStart}Next verification retry:%{noBoldEnd} Retry #%{retryCount} scheduled %{timeAgo}',
    ),
    geoFailure: s__('Geo|Error: %{message}'),
    unknown: __('Unknown'),
  },
  computed: {
    verificationStatus() {
      return (
        VERIFICATION_STATUS_STATES[this.replicableItem?.verificationState] ||
        VERIFICATION_STATUS_STATES.UNKNOWN
      );
    },
    showVerificationStartedAt() {
      return [
        VERIFICATION_STATUS_STATES.PENDING.value,
        VERIFICATION_STATUS_STATES.STARTED.value,
      ].includes(this.replicableItem?.verificationState);
    },
    verificationFailure() {
      return this.replicableItem?.verificationState === VERIFICATION_STATUS_STATES.FAILED.value;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <div class="gl-flex gl-items-center">
        <h5 class="gl-my-0">{{ $options.i18n.verificationInformation }}</h5>
        <help-icon id="verification-information-help-icon" class="gl-ml-2" />
        <gl-popover
          target="verification-information-help-icon"
          placement="top"
          triggers="hover focus"
        >
          <p>
            {{ $options.i18n.verificationHelpText }}
          </p>
          <help-page-link href="administration/geo/disaster_recovery/background_verification">{{
            $options.i18n.learnMore
          }}</help-page-link>
        </gl-popover>
        <gl-button class="gl-ml-auto" @click="$emit('reverify')">{{
          $options.i18n.reverify
        }}</gl-button>
      </div>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.statusBadge">
          <template #badge>
            <gl-badge :variant="verificationStatus.variant">{{
              verificationStatus.title
            }}</gl-badge>
          </template>
        </gl-sprintf>
      </p>

      <template v-if="verificationFailure">
        <p class="gl-mb-0">
          <gl-sprintf :message="$options.i18n.geoFailure">
            <template #message>
              <span class="gl-font-bold gl-text-red-700">{{
                replicableItem.verificationFailure || $options.i18n.unknown
              }}</span>
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0">
          <gl-sprintf :message="s__('Geo|Troubleshooting: %{link}')">
            <template #link>
              <help-page-link
                href="administration/geo/replication/troubleshooting/synchronization_verification"
                target="_blank"
                data-testid="verification-failure-troubleshooting-link"
                >{{ s__('Geo|View troubleshooting docs') }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0 gl-font-bold">
          <gl-sprintf :message="$options.i18n.verificationRetryAt">
            <template #noBold="{ content }">
              <span class="gl-font-normal">{{ content }}</span>
            </template>
            <template #retryCount>
              <span>{{ replicableItem.verificationRetryCount }}</span>
            </template>
            <template #timeAgo>
              <time-ago
                :time="replicableItem.verificationRetryAt"
                data-testid="verification-retry-at-time-ago"
              />
            </template>
          </gl-sprintf>
        </p>
      </template>

      <p v-if="showVerificationStartedAt" class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.verificationStartedAt">
          <template #timeAgo>
            <time-ago
              :time="replicableItem.verificationStartedAt"
              class="gl-font-bold"
              data-testid="verification-started-at-time-ago"
            />
          </template>
        </gl-sprintf>
      </p>

      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.lastVerifiedAt">
          <template #timeAgo>
            <time-ago
              :time="replicableItem.verifiedAt"
              class="gl-font-bold"
              data-testid="last-verified-at-time-ago"
            />
          </template>
        </gl-sprintf>
      </p>

      <p class="gl-mb-0" data-testid="local-verification-checksum">
        <gl-sprintf :message="$options.i18n.verificationChecksum">
          <template #verificationChecksum>
            <span class="gl-font-bold">{{
              replicableItem.verificationChecksum || $options.i18n.unknown
            }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          v-if="replicableItem.verificationChecksum"
          :title="$options.i18n.copy"
          :text="replicableItem.verificationChecksum"
          size="small"
          category="tertiary"
        />
      </p>

      <p
        v-if="replicableItem.checksumMismatch"
        class="gl-mb-0"
        data-testid="expected-verification-checksum"
      >
        <gl-sprintf :message="$options.i18n.expectedVerificationChecksum">
          <template #verificationChecksum>
            <span class="gl-font-bold gl-text-red-700">{{
              replicableItem.verificationChecksumMismatched || $options.i18n.unknown
            }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          v-if="replicableItem.verificationChecksumMismatched"
          :title="$options.i18n.copy"
          :text="replicableItem.verificationChecksumMismatched"
          size="small"
          category="tertiary"
        />
      </p>
    </div>
  </gl-card>
</template>
