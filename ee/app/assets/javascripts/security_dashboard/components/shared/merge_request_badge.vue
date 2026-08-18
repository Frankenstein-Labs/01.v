<script>
import { GlBadge, GlPopover, GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

const ICON_COLOR = {
  opened: 'success',
  closed: 'danger',
  merged: 'info',
};

const ICON = {
  opened: 'issue-open-m',
  closed: 'issue-close',
  merged: 'merge',
};

export default {
  components: {
    GlBadge,
    GlIcon,
    GlPopover,
    GlLink,
    GlSprintf,
  },
  props: {
    mergeRequest: {
      type: Object,
      required: true,
    },
  },
  computed: {
    mergeRequestIdString() {
      return s__('AutoRemediation|!%{mergeRequestIid}');
    },
  },
  methods: {
    getIconVariant(state) {
      return ICON_COLOR[state] || 'subtle';
    },
    getIcon(state) {
      return ICON[state] || 'issue-open-m';
    },
  },
};
</script>

<template>
  <div ref="popover" data-testid="vulnerability-solutions-bulb">
    <gl-badge
      ref="badge"
      variant="neutral"
      icon="merge-request"
      :aria-label="s__('SecurityReports|Has merge request')"
    />
    <gl-popover :target="() => $refs.popover" placement="top">
      <template #title>
        <span>{{ s__('AutoRemediation| 1 Merge Request') }}</span>
      </template>
      <ul class="gl-mb-0 gl-list-none gl-pl-0">
        <li class="gl-mb-2 gl-flex gl-items-center">
          <gl-icon
            :name="getIcon(mergeRequest.state)"
            :size="16"
            :variant="getIconVariant(mergeRequest.state)"
          />
          <gl-link :href="mergeRequest.webUrl" class="gl-ml-3">
            <gl-sprintf :message="mergeRequestIdString">
              <template #mergeRequestIid>{{ mergeRequest.iid }}</template>
            </gl-sprintf>
          </gl-link>
        </li>
      </ul>
    </gl-popover>
  </div>
</template>
