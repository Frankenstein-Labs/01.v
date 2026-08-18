<script>
import { GlIcon, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Policy is invalid'),
  },
  name: 'BreakingChangesIcon',
  components: {
    GlIcon,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: '',
    },
    violationList: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    hasMultipleViolations() {
      return this.violationList.length > 1;
    },
  },
  methods: {
    getViolationData(violation) {
      return {
        content: violation?.content || '',
        link: violation?.link || '',
      };
    },
  },
};
</script>

<template>
  <div>
    <gl-popover :title="$options.i18n.title" :target="id" show-close-button>
      <template v-if="hasMultipleViolations">
        <ul class="gl-pl-5">
          <li
            v-for="(violation, index) in violationList"
            :key="violation.content"
            :data-testid="`violation-item-${index}`"
          >
            <gl-sprintf :message="violation.content">
              <template #link="{ content: linkContent }">
                <gl-link :href="violation.link" target="_blank">{{ linkContent }}</gl-link>
              </template>
            </gl-sprintf>
          </li>
        </ul>
      </template>
      <template v-else>
        <gl-sprintf :message="getViolationData(violationList[0]).content">
          <template #link="{ content: linkContent }">
            <gl-link :href="getViolationData(violationList[0]).link" target="_blank">{{
              linkContent
            }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </gl-popover>
    <gl-icon :id="id" name="error" variant="danger" />
  </div>
</template>
