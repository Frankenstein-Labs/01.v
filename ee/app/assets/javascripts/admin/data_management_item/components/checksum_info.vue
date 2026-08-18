<script>
import { GlSprintf, GlBadge, GlCard, GlButton, GlPopover } from '@gitlab/ui';
import { VERIFICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'ChecksumInfo',
  components: {
    GlSprintf,
    GlBadge,
    GlButton,
    GlCard,
    GlPopover,
    TimeAgo,
    ClipboardButton,
    HelpIcon,
    HelpPageLink,
  },
  props: {
    details: {
      type: Object,
      required: true,
    },
    checksumLoading: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['recalculate-checksum'],
  computed: {
    checksumStatus() {
      const checksumState = this.details.checksumState?.toUpperCase();
      return VERIFICATION_STATUS_STATES[checksumState] || VERIFICATION_STATUS_STATES.UNKNOWN;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <div class="gl-flex gl-items-center">
        <h5 class="gl-my-0">{{ s__('Geo|Checksum information') }}</h5>
        <help-icon id="checksum-information-help-icon" class="gl-ml-2" />
        <gl-popover target="checksum-information-help-icon" placement="top" triggers="hover focus">
          <p>
            {{
              s__(
                "Geo|Verifies data integrity on the primary site by calculating a checksum of the model's data. This can later be used to ensure replicated data matches between primary and secondary Geo sites, helping detect corruption during replication.",
              )
            }}
          </p>
          <help-page-link href="administration/geo/disaster_recovery/background_verification">{{
            __('Learn more')
          }}</help-page-link>
        </gl-popover>
        <gl-button
          class="gl-ml-auto"
          :loading="checksumLoading"
          @click="$emit('recalculate-checksum')"
          >{{ s__('Geo|Checksum') }}</gl-button
        >
      </div>
    </template>

    <div class="gl-flex gl-flex-col gl-items-start gl-gap-4">
      <p class="gl-mb-0" data-testid="checksum-status">
        <gl-sprintf :message="s__('Geo|Status: %{badge}')">
          <template #badge>
            <gl-badge :variant="checksumStatus.variant">{{ checksumStatus.title }}</gl-badge>
          </template>
        </gl-sprintf>
      </p>

      <template v-if="details.checksumFailure">
        <p class="gl-mb-0" data-testid="checksum-failure">
          <gl-sprintf :message="s__('Geo|Error: %{message}')">
            <template #message>
              <span class="gl-font-bold gl-text-danger">{{ details.checksumFailure }}</span>
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0">
          <gl-sprintf :message="s__('Geo|Troubleshooting: %{link}')">
            <template #link>
              <help-page-link
                href="administration/geo/replication/troubleshooting/synchronization_verification"
                target="_blank"
                data-testid="checksum-failure-troubleshooting-link"
                >{{ s__('Geo|View troubleshooting docs') }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0 gl-font-bold" data-testid="checksum-retry">
          <gl-sprintf
            :message="
              s__(
                'Geo|%{noBoldStart}Next checksum retry:%{noBoldEnd} Retry #%{retryCount} scheduled %{timeAgo}',
              )
            "
          >
            <template #noBold="{ content }">
              <span class="gl-font-normal">{{ content }}</span>
            </template>
            <template #retryCount>
              <span>{{ details.retryCount }}</span>
            </template>
            <template #timeAgo>
              <time-ago :time="details.retryAt" />
            </template>
          </gl-sprintf>
        </p>
      </template>

      <p v-if="details.lastChecksum" data-testid="checksum-last" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Last checksum: %{timeAgo}')">
          <template #timeAgo>
            <time-ago :time="details.lastChecksum" class="gl-font-bold" />
          </template>
        </gl-sprintf>
      </p>

      <p data-testid="checksum" class="gl-mb-0">
        <gl-sprintf :message="s__('Geo|Checksum: %{checksum}')">
          <template #checksum>
            <span class="gl-font-bold">{{ details.checksum || __('Unknown') }}</span>
          </template>
        </gl-sprintf>
        <clipboard-button
          v-if="details.checksum"
          :title="__('Copy')"
          :text="details.checksum"
          size="small"
          category="tertiary"
        />
      </p>
    </div>
  </gl-card>
</template>
