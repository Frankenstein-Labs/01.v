<script>
import { GlDrawer, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

const createSectionContent = (obj) =>
  Object.entries(obj)
    .map(([k, v]) => ({ name: k, value: v }))
    .filter((e) => e.value)
    .sort((a, b) => (a.name > b.name ? 1 : -1));

export default {
  name: 'TracingDrawer',
  components: {
    GlDrawer,
    GlLink,
  },
  i18n: {
    spanDetailsTitle: s__('Tracing|Metadata'),
    spanAttributesTitle: s__('Tracing|Attributes'),
    resourceAttributesTitle: s__('Tracing|Resource attributes'),
  },
  props: {
    span: {
      required: false,
      type: Object,
      default: null,
    },
    open: {
      required: true,
      type: Boolean,
    },
  },
  emits: ['close'],
  computed: {
    sections() {
      if (this.span) {
        const {
          span_attributes: spanAttributes,
          resource_attributes: resourceAttributes,
          ...rest
        } = this.span;

        const sections = [
          {
            content: createSectionContent(rest),
            title: this.$options.i18n.spanDetailsTitle,
            key: 'span-details',
          },
        ];
        if (spanAttributes) {
          sections.push({
            title: this.$options.i18n.spanAttributesTitle,
            content: createSectionContent(spanAttributes),
            key: 'span-attributes',
          });
        }
        if (resourceAttributes) {
          sections.push({
            title: this.$options.i18n.resourceAttributesTitle,
            content: createSectionContent(resourceAttributes),
            key: 'resource-attributes',
          });
        }
        return sections;
      }
      return [];
    },
    title() {
      if (this.span) {
        return `${this.span.service_name} : ${this.span.operation}`;
      }
      return '';
    },
    drawerHeaderHeight() {
      // avoid calculating this in advance because it causes layout thrashing
      // https://gitlab.com/gitlab-org/gitlab/-/issues/331172#note_1269378396
      if (!this.open) return '0';
      return getContentWrapperHeight();
    },
  },
  methods: {
    isLink(value) {
      try {
        const parsed = new URL(value);
        return ['http:', 'https:'].includes(parsed.protocol);
      } catch {
        return false;
      }
    },
    hasError(line) {
      return line.name === 'status_code' && line.value === 'STATUS_CODE_ERROR';
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :open="open"
    :z-index="$options.DRAWER_Z_INDEX"
    :header-height="drawerHeaderHeight"
    header-sticky
    @close="$emit('close')"
  >
    <template #title>
      <div data-testid="drawer-title">
        <h2 class="gl-mb-0 gl-mt-0 gl-text-size-h2 gl-wrap-anywhere">{{ title }}</h2>
      </div>
    </template>

    <template #default>
      <div
        v-for="section in sections"
        :key="section.key"
        :data-testid="`section-${section.key}`"
        class="gl-border-none"
      >
        <h2
          v-if="section.title"
          data-testid="section-title"
          class="gl-mb-0 gl-mt-0 gl-text-size-h2"
        >
          {{ section.title }}
        </h2>
        <div
          v-for="line in section.content"
          :key="line.name"
          data-testid="section-line"
          class="gl-border-b-1 gl-border-b-strong gl-py-5 gl-border-b-solid"
          :class="{ 'gl-bg-red-100': hasError(line) }"
        >
          <label data-testid="section-line-name">{{ line.name }}</label>
          <div data-testid="section-line-value" class="gl-wrap-anywhere">
            <gl-link v-if="isLink(line.value)" :href="line.value" target="_blank">
              {{ line.value }}
            </gl-link>
            <template v-else>
              {{ line.value }}
            </template>
          </div>
        </div>
      </div>
    </template>
  </gl-drawer>
</template>
