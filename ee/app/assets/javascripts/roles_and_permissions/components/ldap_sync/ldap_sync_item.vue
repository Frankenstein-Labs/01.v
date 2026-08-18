<script>
import { GlButton, GlIcon, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { getTimeago, duration, localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { s__, __, sprintf } from '~/locale';

const TIME_AGO = getTimeago();
const SYNC_STATUS = {
  NEVER_SYNCED: 'NEVER_SYNCED',
  FAILED: 'FAILED',
  SUCCESSFUL: 'SUCCESSFUL',
  RUNNING: 'RUNNING',
  QUEUED: 'QUEUED',
};

export default {
  name: 'LdapSyncItem',
  components: { GlButton, GlIcon, GlBadge },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    roleLink: {
      type: Object,
      required: true,
    },
  },
  emits: ['delete'],
  data() {
    return {
      isExpanded: false,
      currentTimestamp: new Date(),
    };
  },
  computed: {
    isUnknownLdapServer() {
      return !this.roleLink.provider.label;
    },
    isSyncRunningOrSuccessful() {
      return [SYNC_STATUS.RUNNING, SYNC_STATUS.SUCCESSFUL].includes(this.roleLink.syncStatus);
    },
    moreDetailsText() {
      // Use the end time if available, then the start time, then default to "More details".
      const timestamp = this.roleLink.syncEndedAt || this.roleLink.syncStartedAt;
      return timestamp ? this.formatTimeago(timestamp) : __('More details');
    },
    totalRuntimeString() {
      const { syncStartedAt, syncEndedAt } = this.roleLink;
      if (!syncStartedAt || !syncEndedAt) return '';

      const start = Date.parse(syncStartedAt);
      const end = Date.parse(syncEndedAt);

      return duration(end - start);
    },
    badgeProps() {
      switch (this.roleLink.syncStatus) {
        case SYNC_STATUS.NEVER_SYNCED:
          return { variant: 'neutral', icon: null, text: s__('LDAP|Never synced') };
        case SYNC_STATUS.QUEUED:
          return { variant: 'warning', icon: 'status_pending', text: __('Queued') };
        case SYNC_STATUS.RUNNING:
          return { variant: 'info', icon: 'status_running', text: __('Running') };
        case SYNC_STATUS.SUCCESSFUL:
          return { variant: 'success', icon: 'status_success_solid', text: __('Success') };
        case SYNC_STATUS.FAILED:
          return { variant: 'danger', icon: 'status_failed', text: __('Failed') };
        default:
          return { variant: 'neutral', icon: 'question', text: this.roleLink.syncStatus };
      }
    },
  },
  methods: {
    formatTimeago(timestamp) {
      return TIME_AGO.format(timestamp, undefined, { relativeDate: this.currentTimestamp });
    },
    getDateString(timestamp) {
      const dateTime = localeDateFormat.asDateTimeFull.format(newDate(timestamp));
      const timeAgo = this.formatTimeago(timestamp);

      return sprintf(s__('LDAP|%{dateTime} (%{timeAgo})'), { dateTime, timeAgo });
    },
  },
  dtClass: 'gl-mb-1 last-of-type:gl-mb-0',
  ddClass: 'gl-text-subtle last-of-type:gl-mb-0',
};
</script>

<template>
  <li class="gl-flex-row-reverse gl-items-center @sm/panel:!gl-flex">
    <gl-button
      variant="danger"
      category="secondary"
      icon="remove"
      :aria-label="s__('MemberRole|Remove sync')"
      class="gl-float-right gl-ml-3 gl-mt-2"
      @click="$emit('delete')"
    />

    <dl class="gl-mb-0 gl-flex-1 gl-grid-cols-[auto_1fr] gl-gap-x-5 @sm/panel:gl-grid">
      <dt :class="$options.dtClass">{{ s__('MemberRole|Server:') }}</dt>
      <dd :class="{ ...$options.ddClass, 'gl-text-warning': isUnknownLdapServer }">
        {{ roleLink.provider.label || roleLink.provider.id }}
        <gl-icon
          v-if="isUnknownLdapServer"
          v-gl-tooltip.d0="
            s__('MemberRole|Unknown LDAP server. Please check your server settings.')
          "
          name="warning-solid"
          variant="warning"
          class="gl-ml-1"
        />
      </dd>

      <template v-if="roleLink.filter">
        <dt :class="$options.dtClass">{{ s__('MemberRole|User filter:') }}</dt>
        <dd :class="$options.ddClass">{{ roleLink.filter }}</dd>
      </template>

      <template v-else-if="roleLink.cn">
        <dt :class="$options.dtClass">{{ s__('MemberRole|Group cn:') }}</dt>
        <dd :class="$options.ddClass">{{ roleLink.cn }}</dd>
      </template>

      <dt :class="$options.dtClass">{{ s__('MemberRole|Custom admin role:') }}</dt>
      <dd :class="$options.ddClass">
        {{ roleLink.adminMemberRole.name }}
      </dd>

      <dt :class="$options.dtClass" class="@md/panel:gl-mt-1">
        {{ s__('MemberRole|Sync status:') }}
      </dt>
      <dd :class="$options.ddClass">
        <gl-badge :icon="badgeProps.icon" :variant="badgeProps.variant" class="gl-align-middle">
          {{ badgeProps.text }}
        </gl-badge>
        <gl-button variant="link" class="gl-ml-2" @click="isExpanded = !isExpanded">
          {{ moreDetailsText }}
          <gl-icon :name="isExpanded ? 'chevron-up' : 'chevron-down'" />
        </gl-button>
      </dd>

      <template v-if="isExpanded">
        <template v-if="roleLink.syncStartedAt">
          <dt :class="$options.dtClass"><gl-icon name="play" /> {{ s__('LDAP|Started at:') }}</dt>
          <dd :class="$options.ddClass">{{ getDateString(roleLink.syncStartedAt) }}</dd>
        </template>

        <template v-if="roleLink.syncEndedAt">
          <dt :class="$options.dtClass"><gl-icon name="stop" /> {{ s__('LDAP|Ended at:') }}</dt>
          <dd :class="$options.ddClass">{{ getDateString(roleLink.syncEndedAt) }}</dd>
        </template>

        <template v-if="totalRuntimeString">
          <dt :class="$options.dtClass">
            <gl-icon name="timer" /> {{ s__('LDAP|Total runtime:') }}
          </dt>
          <dd :class="$options.ddClass">{{ totalRuntimeString }}</dd>
        </template>

        <template v-if="roleLink.syncError">
          <dt :class="$options.dtClass"><gl-icon name="error" /> {{ s__('LDAP|Sync error:') }}</dt>
          <dd :class="$options.ddClass">{{ roleLink.syncError }}</dd>
        </template>

        <template v-if="roleLink.lastSuccessfulSyncAt && !isSyncRunningOrSuccessful">
          <dt :class="$options.dtClass">
            <gl-icon name="check" /> {{ s__('LDAP|Last successful sync:') }}
          </dt>
          <dd :class="$options.ddClass">{{ getDateString(roleLink.lastSuccessfulSyncAt) }}</dd>
        </template>

        <dt :class="$options.dtClass">
          <gl-icon name="file-addition" /> {{ s__('LDAP|Sync created at:') }}
        </dt>
        <dd :class="$options.ddClass">{{ getDateString(roleLink.createdAt) }}</dd>
      </template>
    </dl>
  </li>
</template>
