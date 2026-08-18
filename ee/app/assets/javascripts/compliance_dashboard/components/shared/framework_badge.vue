<script>
import { GlButton, GlLabel, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_FRAMEWORKS } from '../../constants';

export default {
  name: 'ComplianceFrameworkBadge',
  components: {
    GlLabel,
    GlButton,
    GlPopover,
  },
  inject: {
    namespaceId: {
      default: null,
    },
  },
  props: {
    framework: {
      type: Object,
      required: true,
    },
    showDefault: {
      type: Boolean,
      required: false,
      default: true,
    },
    closeable: {
      type: Boolean,
      required: false,
      default: false,
    },
    popoverMode: {
      type: String,
      required: true,
      default: 'details',
      validator: (value) => ['details', 'hidden', 'edit', 'disabled'].includes(value),
    },
    viewDetailsUrl: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['close'],
  computed: {
    showDefaultBadge() {
      return this.showDefault && this.framework.default;
    },
    isEditMode() {
      return this.popoverMode === 'edit';
    },
    isDisabled() {
      return this.popoverMode === 'disabled';
    },
    showPopover() {
      return this.popoverMode !== 'hidden';
    },
    isCSPFramework() {
      if (!this.framework.namespaceId || !this.namespaceId) {
        return false;
      }

      return (
        getIdFromGraphQLId(this.framework.namespaceId) !== getIdFromGraphQLId(this.namespaceId)
      );
    },
    frameworkName() {
      const maxLength = 30;
      const name =
        this.framework?.name?.length > maxLength
          ? `${this.framework.name.substring(0, maxLength)}...`
          : this.framework.name;
      return this.showDefaultBadge ? `${name} (${this.$options.i18n.default})` : name;
    },
    frameworkTestId() {
      return this.showDefaultBadge
        ? 'compliance-framework-default-label'
        : 'compliance-framework-label';
    },
    frameworkId() {
      return getIdFromGraphQLId(this.framework.id);
    },
  },
  methods: {
    editFromPopover() {
      this.$router.push({
        name: ROUTE_EDIT_FRAMEWORK,
        params: { id: this.frameworkId },
      });
    },
    viewFrameworkDetails() {
      if (this.viewDetailsUrl) {
        visitUrl(this.viewDetailsUrl);
      } else {
        this.$router.push({
          name: ROUTE_FRAMEWORKS,
          query: { id: this.frameworkId },
        });
      }
    },
  },
  i18n: {
    default: s__('ComplianceFrameworks|default'),
    edit: s__('ComplianceReport|Edit the framework'),
    viewDetails: s__('ComplianceReport|View the framework details'),
    disabledText: s__(
      'ComplianceReport|Only group owners and maintainers can view the framework details',
    ),
    CSPFramework: s__('ComplianceFramework|Instance level compliance framework'),
  },
};
</script>

<template>
  <div ref="badge">
    <gl-popover
      v-if="showPopover"
      ref="popover"
      :title="framework.name"
      :target="() => $refs.label"
    >
      <div v-if="framework.description" class="gl-mb-3 gl-text-left">
        {{ framework.description }}
      </div>

      <div v-if="isCSPFramework" class="gl-border-t gl-mb-2 gl-pt-2 gl-text-sm gl-text-subtle">
        {{ $options.i18n.CSPFramework }}
      </div>

      <div class="gl-text-left">
        <gl-button
          v-if="isEditMode"
          category="secondary"
          size="small"
          variant="confirm"
          class="gl-text-sm"
          @click="editFromPopover"
        >
          {{ $options.i18n.edit }}
        </gl-button>
        <template v-else>
          <div v-if="isDisabled" class="gl-mb-3">{{ $options.i18n.disabledText }}</div>
          <gl-button
            category="secondary"
            size="small"
            variant="confirm"
            class="gl-mb-2 gl-text-sm"
            :disabled="isDisabled"
            @click="viewFrameworkDetails"
          >
            {{ $options.i18n.viewDetails }}
          </gl-button>
        </template>
      </div>
    </gl-popover>
    <span ref="label">
      <gl-label
        :data-testid="frameworkTestId"
        :background-color="framework.color"
        :title="frameworkName"
        :show-close-button="closeable"
        class="@md/panel:gl-max-w-26"
        @close="$emit('close')"
      />
    </span>
  </div>
</template>
