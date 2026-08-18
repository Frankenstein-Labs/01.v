<script>
import { GlIcon, GlIntersperse, GlLink, GlPopover, GlTruncate, GlButton } from '@gitlab/ui';
import { n__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DEPENDENCIES_TABLE_I18N } from '../constants';
import DirectDescendantViewer from './direct_descendant_viewer.vue';

export const VISIBLE_DEPENDENCY_COUNT = 2;
export const CONTAINER_IMAGE_PREFIX = 'container-image:';

export default {
  name: 'DependencyLocation',
  components: {
    DirectDescendantViewer,
    GlIcon,
    GlIntersperse,
    GlLink,
    GlPopover,
    GlTruncate,
    GlButton,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    location: {
      type: Object,
      required: true,
    },
    hasDependencyPaths: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['click-dependency-path'],
  computed: {
    ancestors() {
      return this.location.ancestors || [];
    },
    locationComponent() {
      return this.isContainerImageDependency ? 'span' : GlLink;
    },
    hasAncestors() {
      return this.ancestors.length > 0;
    },
    isContainerImageDependency() {
      return this.location.path.startsWith(CONTAINER_IMAGE_PREFIX);
    },
    locationPath() {
      if (this.isContainerImageDependency) {
        return this.location.path.slice(CONTAINER_IMAGE_PREFIX.length);
      }

      return this.location.path;
    },
    isTopLevelDependency() {
      return this.location.topLevel;
    },
    visibleDependencies() {
      return this.ancestors.slice(0, VISIBLE_DEPENDENCY_COUNT);
    },
    remainingDependenciesCount() {
      return Math.max(0, this.ancestors.length - VISIBLE_DEPENDENCY_COUNT);
    },
    showMoreLink() {
      return this.remainingDependenciesCount > 0;
    },
    nMoreMessage() {
      return n__('Dependencies|%d more', 'Dependencies|%d more', this.remainingDependenciesCount);
    },
    hasPaths() {
      return this.location.path && this.location.blobPath;
    },
  },
  methods: {
    target() {
      /**
       * When the dependency list reloads during filtering, the component temporarily unmounts
       * while updating, causing $refs.moreLink to become undefined. When migrated to Vue 3,
       * we can use optional chaining in templates.
       *
       * Fix is similar to:
       * https://gitlab.com/gitlab-org/gitlab/-/merge_requests/49628#note_464803276
       */
      return this.$refs.moreLink?.$el;
    },
  },
  i18n: DEPENDENCIES_TABLE_I18N,
};
</script>

<template>
  <div>
    <gl-intersperse separator=" / " class="gl-text-subtle">
      <!-- We need to put an extra span to avoid separator between path & top level label -->
      <span>
        <component
          :is="locationComponent"
          v-if="hasPaths"
          class="gl-flex gl-items-center gl-justify-end gl-gap-2 @md/panel:gl-justify-start @md/panel:gl-whitespace-nowrap"
          data-testid="dependency-path"
          :href="location.blobPath"
        >
          <gl-icon v-if="isContainerImageDependency" name="container-image" class="gl-shrink-0" />
          <gl-icon v-else name="doc-text" class="gl-shrink-0" />
          <gl-truncate
            class="gl-hidden @md/panel:gl-inline-flex"
            position="start"
            :text="locationPath"
            with-tooltip
          />
          <span class="@md/panel:gl-hidden">{{ locationPath }}</span>
        </component>
        <span v-else>{{ $options.i18n.unknown }}</span>
        <span v-if="isTopLevelDependency">{{ s__('Dependencies|(top level)') }}</span>
      </span>

      <direct-descendant-viewer
        v-if="hasAncestors && !glFeatures.dependencyPaths"
        :dependencies="visibleDependencies"
      />

      <!-- We need to put an extra span to avoid separator between link & popover -->
      <span v-if="showMoreLink && !glFeatures.dependencyPaths">
        <gl-link ref="moreLink" class="gl-whitespace-nowrap">{{ nMoreMessage }}</gl-link>

        <gl-popover :target="target" placement="top" :title="s__('Dependencies|Direct dependents')">
          <direct-descendant-viewer :dependencies="ancestors" data-testid="popover-body" />
        </gl-popover>
      </span>
    </gl-intersperse>
    <gl-button
      v-if="glFeatures.dependencyPaths && hasDependencyPaths"
      class="gl-mt-2 gl-block gl-justify-self-end @md/panel:gl-justify-self-start"
      size="small"
      @click="$emit('click-dependency-path')"
      >{{ $options.i18n.dependencyPathButtonText }}</gl-button
    >
  </div>
</template>
