<script>
import { uniqueId } from 'lodash-es';
import { GlSkeletonLoader, GlIcon, GlPopover, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { REPORT_TYPE_PRESETS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import { VULNERABILITY_STATE_OBJECTS } from 'ee/vulnerabilities/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import getProjectContainerScanning from '../../graphql/queries/get_project_container_scanning.query.graphql';

const { detected, confirmed } = VULNERABILITY_STATE_OBJECTS;

export default {
  name: 'MetadataContainerScanning',
  components: {
    GlIcon,
    GlSkeletonLoader,
    GlPopover,
    GlLink,
  },
  inject: ['config'],
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    containerScanningData: {
      query: getProjectContainerScanning,
      variables() {
        return {
          fullPath: this.config.projectPath,
          securityConfigurationPath: this.config.securityConfigurationPath,
          reportType: REPORT_TYPE_PRESETS.CONTAINER_REGISTRY,
          state: [detected.searchParamValue, confirmed.searchParamValue],
        };
      },
      update(data) {
        return (
          data.project.containerScanningForRegistry ?? {
            isEnabled: false,
            isVisible: false,
          }
        );
      },
    },
  },
  computed: {
    isMetaVisible() {
      return this.containerScanningData?.isVisible;
    },
    metaText() {
      return this.containerScanningData?.isEnabled
        ? s__('ContainerRegistry|Container scanning for registry: On')
        : s__('ContainerRegistry|Container scanning for registry: Off');
    },
    popoverContainerId() {
      return uniqueId('container-scanning-metadata-popover-');
    },
  },
  methods: {
    popoverTarget() {
      return this.$refs.shieldIcon?.$el;
    },
  },
  containerScanningForRegistryHelpUrl: helpPagePath(
    'user/application_security/continuous_vulnerability_scanning/_index',
  ),
};
</script>

<template>
  <div class="gl-inline-flex gl-items-center">
    <gl-skeleton-loader v-if="$apollo.queries.containerScanningData.loading" :lines="1" />
    <template v-if="isMetaVisible">
      <div :id="popoverContainerId" data-testid="container-scanning-metadata">
        <gl-icon
          ref="shieldIcon"
          name="shield"
          class="gl-mr-3 gl-min-w-5"
          variant="subtle"
          :aria-label="metaText"
          data-testid="container-scanning-shield-icon"
        /><span class="gl-inline-flex">{{ metaText }}</span>
      </div>
      <gl-popover
        data-testid="container-scanning-metadata-popover"
        :target="popoverTarget"
        :container="popoverContainerId"
        triggers="hover focus click"
        placement="bottom"
      >
        {{
          s__(
            'ContainerRegistry|Continuous container scanning runs in the registry when any image or database is updated.',
          )
        }}
        <br />
        <br />
        <gl-link
          :href="$options.containerScanningForRegistryHelpUrl"
          target="_blank"
          class="gl-font-bold"
        >
          {{ __('What is continuous container scanning?') }}
        </gl-link>
      </gl-popover>
    </template>
  </div>
</template>
