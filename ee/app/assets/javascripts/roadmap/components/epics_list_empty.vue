<script>
import { GlEmptyState } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { localeDateFormat, nDaysAfter } from '~/lib/utils/datetime_utility';
import { s__, sprintf } from '~/locale';

import {
  emptyStateDefault,
  emptyStateWithFilters,
  emptyStateWithEpicIidFiltered,
} from '../constants';
import CommonMixin from '../mixins/common_mixin';

export default {
  name: 'EpicsListEmpty',
  components: {
    GlEmptyState,
  },
  directives: {
    SafeHtml,
  },
  mixins: [CommonMixin],
  inject: [
    'newEpicPath',
    'listEpicsPath',
    'epicsDocsPath',
    'canCreateEpic',
    'emptyStateIllustrationPath',
    'isChildEpics',
  ],
  props: {
    // eslint-disable-next-line vue/no-unused-properties -- This is used in CommonMixin.
    presetType: {
      type: String,
      required: true,
    },
    timeframeStart: {
      type: [Date, Object],
      required: true,
    },
    timeframeEnd: {
      type: [Date, Object],
      required: true,
    },
    hasFiltersApplied: {
      type: Boolean,
      required: true,
    },
    filterParams: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    timeframeRange() {
      let startDate;
      let endDate;

      if (this.presetTypeQuarters) {
        startDate = this.timeframeStart.range.at(0);
        endDate = this.timeframeEnd.range.at(2);
      } else if (this.presetTypeMonths) {
        startDate = this.timeframeStart;
        endDate = this.timeframeEnd;
      } else if (this.presetTypeWeeks) {
        startDate = this.timeframeStart;
        endDate = nDaysAfter(this.timeframeEnd, 6);
      }

      return localeDateFormat.asDate.formatRange(startDate, endDate);
    },
    message() {
      if (this.hasFiltersApplied) {
        return s__('GroupRoadmap|Sorry, no epics matched your search');
      }
      return s__('GroupRoadmap|The roadmap shows the progress of your epics along a timeline');
    },
    subMessage() {
      if (this.isChildEpics) {
        return sprintf(
          s__(
            'GroupRoadmap|To view the roadmap, add a start or due date to one of the %{linkStart}child epics%{linkEnd}.',
          ),
          {
            linkStart: `<a href="${this.epicsDocsPath}#multi-level-child-epics" target="_blank" rel="noopener noreferrer nofollow">`,
            linkEnd: '</a>',
          },
          false,
        );
      }

      if (this.hasFiltersApplied && Boolean(this.filterParams?.epicIid)) {
        return emptyStateWithEpicIidFiltered;
      }

      if (this.hasFiltersApplied) {
        return sprintf(emptyStateWithFilters, { dateRange: this.timeframeRange });
      }

      return sprintf(emptyStateDefault, { dateRange: this.timeframeRange });
    },
    extraProps() {
      const props = {};

      if (this.canCreateEpic && !this.hasFiltersApplied) {
        props.primaryButtonLink = this.newEpicPath;
        props.primaryButtonText = s__('GroupRoadmap|New epic');
      }

      return {
        secondaryButtonLink: this.listEpicsPath,
        secondaryButtonText: s__('GroupRoadmap|View epics list'),
        ...props,
      };
    },
  },
};
</script>

<template>
  <gl-empty-state
    :title="message"
    :svg-path="emptyStateIllustrationPath"
    data-testid="epics-list-empty-state"
    v-bind="extraProps"
  >
    <template #description>
      <p v-safe-html="subMessage" data-testid="sub-title"></p>
    </template>
  </gl-empty-state>
</template>
