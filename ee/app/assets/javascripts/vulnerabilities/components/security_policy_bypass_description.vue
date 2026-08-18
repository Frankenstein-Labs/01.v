<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  name: 'SecurityPolicyBypassDescription',
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
    TimeAgoTooltip,
  },
  directives: {
    SafeHtml,
  },
  props: {
    bypass: {
      type: Object,
      required: true,
    },
    /*
     * Aligns the icon circle and row rhythm with the vulnerability details
     * enrichment activity feed's timeline spine.
     */
    feedAligned: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    rootTag() {
      return this.feedAligned ? 'li' : 'div';
    },
    rootClass() {
      return this.feedAligned ? 'gl-group gl-relative gl-isolate' : null;
    },
    rowClass() {
      return this.feedAligned ? 'gl-my-5 group-first:gl-mt-0 group-last:gl-mb-0' : 'gl-mt-6';
    },
    iconCircleClass() {
      return this.feedAligned
        ? 'gl-float-left gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-bg-strong gl-text-subtle'
        : 'gl-float-left !gl-m-0 -gl-mt-1 gl-ml-2 gl-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-bg-strong gl-text-subtle';
    },
    contentClass() {
      return this.feedAligned ? 'gl-ml-8' : 'gl-ml-5';
    },
    bypassReasons() {
      return Array.isArray(this.bypass.dismissalTypes) ? this.bypass.dismissalTypes.join(', ') : '';
    },
    bypassReasonsText() {
      return sprintf(s__('VulnerabilityManagement|Reason category: %{reasons}'), {
        reasons: this.bypassReasons,
      });
    },
    bypassMRText() {
      return s__('VulnerabilityManagement|Bypassed by %{user} in merge request %{mr}');
    },
    comment() {
      return this.bypass.comment;
    },
    commentText() {
      return sprintf(s__('VulnerabilityManagement|Reason detail: %{comment}'), {
        comment: this.comment,
      });
    },
    showUserAndMR() {
      const { mergeRequestPath, mergeRequestReference, userName, userPath } = this.bypass;
      return mergeRequestPath && mergeRequestReference && userName && userPath;
    },
    statusText() {
      return s__('VulnerabilityManagement|%{statusStart}Bypassed%{statusEnd} · %{timeago}');
    },
    time() {
      return this.bypass.createdAt;
    },
  },
};
</script>

<template>
  <component :is="rootTag" :class="rootClass">
    <div
      v-if="feedAligned"
      aria-hidden="true"
      class="gl-absolute -gl-top-5 gl-left-0 -gl-z-1 gl-flex gl-h-5 gl-w-6 gl-justify-center group-first:gl-hidden"
    >
      <div class="gl-w-1 gl-bg-strong"></div>
    </div>
    <div
      v-if="feedAligned"
      aria-hidden="true"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-top-0 -gl-z-1 gl-flex gl-w-6 gl-justify-center group-last:gl-hidden"
    >
      <div class="gl-w-1 gl-bg-strong"></div>
    </div>
    <div :class="rowClass">
      <div :class="iconCircleClass" aria-hidden="true">
        <gl-icon name="warning" class="circle-icon-container" variant="subtle" />
      </div>
      <div :class="contentClass">
        <gl-sprintf v-if="time" :message="statusText">
          <template #status="{ content }">
            <span class="gl-ml-5 gl-font-bold" data-testid="status">{{ content }}</span>
          </template>
          <template #timeago>
            <time-ago-tooltip ref="timeAgo" :time="time" />
          </template>
        </gl-sprintf>
        <ul class="gl-ml-5">
          <li>{{ s__('SecurityOrchestration|Security policy violated') }}</li>
          <li v-if="bypassReasons">{{ bypassReasonsText }}</li>
          <li v-if="comment" v-safe-html="commentText"></li>
          <li v-if="showUserAndMR">
            <gl-sprintf :message="bypassMRText">
              <template #user>
                <gl-link target="_blank" :href="bypass.userPath">{{ bypass.userName }}</gl-link>
              </template>
              <template #mr>
                <gl-link target="_blank" :href="bypass.mergeRequestPath">{{
                  bypass.mergeRequestReference
                }}</gl-link>
              </template>
            </gl-sprintf>
          </li>
        </ul>
      </div>
    </div>
  </component>
</template>
